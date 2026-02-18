import Ecto.Query, only: [from: 2]

defmodule OasWeb.Schema.SchemaTrainingWhere do
  use Absinthe.Schema.Notation

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
  end

  object :training_where_mutations do
    field :training_where, type: :training_where do
      arg :id, :integer
      arg :name, non_null(:string)
      arg :credit_amount, non_null(:string)
      arg :billing_type, :billing_type, default_value: nil
      arg :gocardless_name, :string, default_value: nil
      arg :billing_config, :json, default_value: nil
      resolve fn _, args, _ ->

        args = case Map.get(args, :gocardless_name) do
          nil -> args |> Map.put(:gocardless, nil)
          gcn -> args |> Map.put(:gocardless, %{
            name: gcn,
            type: :member
          })
        end

        training_where = case args do
          %{id: id} -> Oas.Repo.get(Oas.Trainings.TrainingWhere, id)
            |> Oas.Repo.preload(:gocardless)
          _ -> %Oas.Trainings.TrainingWhere{}
        end

        args = case !is_nil(training_where.gocardless) and Map.has_key?(training_where.gocardless, :id) and !is_nil(args.gocardless) do
          true -> args |> put_in([:gocardless, :id], training_where.gocardless.id)
          false -> args
        end

        training_where
        |> Oas.Trainings.TrainingWhere.changeset(args)
        |> dbg
        |> (&(case &1 do
          %{data: %{id: nil}} -> Oas.Repo.insert(&1)
          %{data: %{id: _}} -> Oas.Repo.update(&1)
        end)).()
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
  end
end
