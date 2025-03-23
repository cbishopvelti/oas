import Ecto.Query, only: [from: 2]
defmodule OasWeb.Schema.SchemaTrainingWhere do
  use Absinthe.Schema.Notation

  object :training_where_queries do
    field :training_where, :training_where do
      arg :id, non_null(:integer)
      resolve fn _, %{id: id}, _ ->
        result = Oas.Repo.get(Oas.Trainings.TrainingWhere, id)
        result = if (Map.get(result, :cutoff_booking, nil) != nil) do
          duration = Map.get(result, :cutoff_booking)
          IO.inspect(duration, label: "006")
          duration_string = "#{Map.get(duration, :hour, "00")}:#{Map.get(duration, :minute, "00") |> to_string() |> String.pad_leading(2, "0")}"
          %{result | cutoff_booking: duration_string}
        else
          result
        end

        {:ok, result}
      end
    end
  end

  object :training_where_mutations do
    field :training_where, type: :training_where do
      arg :id, :integer
      arg :name, non_null(:string)
      arg :credit_amount, non_null(:string)
      arg :time, :string
      arg :cutoff_booking, :string
      resolve fn _, args, _ ->

        # if (Map.get(args, :time, nil) != nil) do
        #   args = Map.put(args, :time, Time.from_iso8601!(Map.get(args, :time)))
        # end

        IO.inspect(args, label: "107")

        args = if (Map.get(args, :cutoff_booking, "") != "") do
          result = Regex.run(~r/^(\d{0,3}):?(\d{0,2})$/, Map.get(args, :cutoff_booking), capture: :all_but_first)
          result = result |> Enum.map(fn "" -> 0
            x -> String.to_integer(x)
          end)
          args = Map.put(args, :cutoff_booking,
            Duration.new!(hour: result |> Enum.at(0), minute: result |> Enum.at(1)) # |> Duration.to_iso8601()
          )
        else
          args
        end

        result = case args do
          %{id: id} -> Oas.Repo.get(Oas.Trainings.TrainingWhere, id)
          _ -> %Oas.Trainings.TrainingWhere{}
        end
        |> Ecto.Changeset.cast(args, [:name, :credit_amount, :time, :cutoff_booking])
        |> (&(case &1 do
          %{data: %{id: nil}} -> Oas.Repo.insert(&1)
          %{data: %{id: _}} -> Oas.Repo.update(&1)
        end)).()
        |> OasWeb.Schema.SchemaUtils.handle_error
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
              result = training_where
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
  end
end
