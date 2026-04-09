import Ecto.Query, only: [from: 2]
alias Ecto.Multi

defmodule OasWeb.Schema.SchemaTrainingWhere do
  use Absinthe.Schema.Notation

  object :training_where_account_liability do
    field :what, :string
    field :when, :string
    field :amount, :string
    field :acc_amount, :string
    field :transaction_id, :integer
    field :training_id, :integer
  end

  object :training_where_queries do
    field :training_where, :training_where do
      arg :id, non_null(:integer)
      resolve fn _, %{id: id}, _ ->
        # result = Oas.Repo.get(Oas.Trainings.TrainingWhere, id)
        result = from(tw in Oas.Trainings.TrainingWhere,
          preload: [:training_where_time, :gocardless],
          where: tw.id == ^id
        )
        |> Oas.Repo.one!()

        result = case result.gocardless do
          nil -> result
          gc -> result |> Map.put(:gocardless_name, gc.name)
        end

        {:ok, result}
      end
    end
    field :training_where_time, :training_where_time do
      arg :id, non_null(:integer)
      resolve fn _, %{id: id}, _ ->
        result = Oas.Repo.get!(Oas.Trainings.TrainingWhereTime, id)
        {:ok, result}
      end
    end
    field :training_where_time_by_date, :training_where_time do
      arg :training_where_id, non_null(:integer)
      arg :when, non_null(:string)
      resolve fn _, %{training_where_id: training_where_id, when: when1}, _ ->
        result = from(twt in Oas.Trainings.TrainingWhereTime,
          where: twt.training_where_id == ^(training_where_id) and
          twt.day_of_week == ^(Date.day_of_week(
            Date.from_iso8601!(when1)
          ))
        ) |> Oas.Repo.one()

        {:ok, result}
      end
    end

    field :training_where_account_liability, list_of(:training_where_account_liability) do
      arg :id, non_null(:integer)
      resolve fn _, %{id: id}, _ ->
        {_total, result} = Oas.Trainings.TrainingWhere.get_account_liability(id)
        out = result |> Enum.map(fn {acc_amount, amount, item} ->
          item
          |> Map.put(:acc_amount, acc_amount)
          |> Map.put(:amount, amount)
        end)

        {:ok, out}
      end
    end
  end

  object :training_where_mutations do
    field :training_where, type: :training_where do
      arg :id, :integer
      arg :name, non_null(:string)
      arg :credit_amount, non_null(:string)
      arg :billing_type, :billing_type, default_value: nil
      arg :gocardless_name, :string, default_value: nil
      arg :billing_config, :json, default_value: nil
      arg :limit, :integer
      resolve fn _, args, _ ->
        training_where =
          case args do
            %{id: id} ->
                Oas.Repo.get(Oas.Trainings.TrainingWhere, id)
                |> Oas.Repo.preload(:gocardless)
            _ ->
                %Oas.Trainings.TrainingWhere{}
          end

        # 1. Flag if we need to sweep up the record later
        needs_deletion? =
            case Map.fetch(args, :gocardless_name) do
            {:ok, gcn} when gcn in [nil, ""] -> true
            _ -> false
            end

        args =
            case Map.fetch(args, :gocardless_name) do
            :error ->
                args

            {:ok, gcn} when gcn in [nil, ""] ->
                # Nilify triggers the schema to drop the foreign key cleanly
                Map.put(args, :gocardless, nil)

            {:ok, gcn} ->
                gocardless_params = %{name: gcn, type: :training_where}

                gocardless_params =
                if training_where.gocardless && training_where.gocardless.id do
                    Map.put(gocardless_params, :id, training_where.gocardless.id)
                else
                    gocardless_params
                end

                Map.put(args, :gocardless, gocardless_params)
            end

        changeset = Oas.Trainings.TrainingWhere.changeset(training_where, args)

        # 2. Use Ecto.Multi to sequence the disconnect -> delete
        Multi.new()
        |> Multi.insert_or_update(:training_where, changeset)
        |> Multi.run(:delete_gocardless, fn repo, _changes ->
            if needs_deletion? && training_where.gocardless do
            # Now that TrainingWhere has dropped the ID, we can safely delete
            repo.delete(training_where.gocardless)
            else
            {:ok, nil}
            end
        end)
        |> Oas.Repo.transaction()
        |> case do
            # 3. Format the response to fit your existing pipeline
            {:ok, %{training_where: updated_tw}} ->
            {:ok, updated_tw}

            {:error, :training_where, failed_changeset, _} ->
            {:error, failed_changeset}

            {:error, :delete_gocardless, failed_changeset, _} ->
            {:error, failed_changeset}
        end
        |> OasWeb.Schema.SchemaUtils.handle_errors_with_assoc()
      end
    end
    field :training_where_time, type: :training_where_time do
      arg :id, :integer
      arg :training_where_id, non_null(:integer)
      arg :day_of_week, :integer
      arg :start_time, non_null(:string)
      arg :booking_offset, :string
      arg :end_time, :string
      arg :recurring, :boolean
      arg :credit_amount, :string
      arg :limit, :integer
      resolve fn _, args, _ ->
        out = case args do
          %{id: id} -> Oas.Repo.get(Oas.Trainings.TrainingWhereTime, id)
          _ -> %Oas.Trainings.TrainingWhereTime{}
        end
        |> Oas.Trainings.TrainingWhereTime.changeset(args)
        |> (&(case &1 do
          %{data: %{id: nil}} -> Oas.Repo.insert(&1)
          %{data: %{id: _}} -> Oas.Repo.update(&1)
        end)).()
        |> OasWeb.Schema.SchemaUtils.handle_error

        GenServer.cast(Oas.Trainings.RecurringServer, :rerun)
        out
      end
    end
    field :delete_training_where, type: :success do
      arg :id, :integer
      resolve fn _, %{id: id}, _ ->
        case Oas.Repo.get(Oas.Trainings.TrainingWhere, id) do
          nil ->
            {:error, "Training where with id #{id} not found"}
          training_where ->
            try do
              training_where
              |> Ecto.Changeset.change()
              |> Ecto.Changeset.no_assoc_constraint(
                :trainings
              )
              |> Oas.Repo.delete()
              {:ok, %{success: true}}
            rescue
              e in Ecto.ConstraintError ->
                case e do
                  %Ecto.ConstraintError{type: :foreign_key} ->
                    {:error, %{id: id, message: "A training my be using this venue"}}
                  _ -> reraise e, __STACKTRACE__
                end
            end
        end
      end
    end
    field :delete_training_where_time, type: :success do
      arg :id, non_null(:integer)
      resolve fn _, %{id: id}, _ ->
        Oas.Repo.get(Oas.Trainings.TrainingWhereTime, id)
        |> Oas.Repo.delete()

        {:ok, %{success: true}}
      end
    end
    # Similar to schema_member.ex :gocardless_who_link
    field :gocardless_training_where_link, type: :success do
      arg :training_where_id, non_null(:integer)
      arg :gocardless_name, non_null(:string)
      resolve fn _, %{training_where_id: training_where_id, gocardless_name: gocardless_name}, _ ->

        training_where = Oas.Repo.get!(Oas.Trainings.TrainingWhere, training_where_id)
        |> Oas.Repo.preload(:gocardless)

        gocardless_id = case training_where.gocardless do
          nil -> nil
          %{id: id} -> id
        end

        result = training_where
        |> Ecto.Changeset.cast(%{
          gocardless: %{
            id: gocardless_id,
            name: gocardless_name,
            type: :training_where
          }
        }, [])
        |> Ecto.Changeset.cast_assoc(:gocardless, with: &Oas.Gocardless.GocardlessEcto.changeset/2)
        |> Oas.Repo.update()
        |> OasWeb.Schema.SchemaUtils.handle_errors_with_assoc()

        case result do
          {:error, error} -> {:error, error}
          {:ok, _res} -> {:ok, %{success: true}}
        end
      end
    end
  end
end
