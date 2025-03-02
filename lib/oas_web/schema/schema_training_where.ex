import Ecto.Query, only: [from: 2]
defmodule OasWeb.Schema.SchemaTrainingWhere do
  use Absinthe.Schema.Notation

  object :training_where_queries do
    field :training_where, :training_where do
      arg :id, non_null(:integer)
      resolve fn _, %{id: id}, _ ->
        result = Oas.Repo.get(Oas.Trainings.TrainingWhere, id)

        {:ok, result}
      end
    end
  end

  object :training_where_mutations do
    field :training_where, type: :training_where do
      arg :id, :integer
      arg :name, non_null(:string)
      arg :credit_amount, non_null(:string)
      resolve fn _, args, _ ->
        result = case args do
          %{id: id} -> Oas.Repo.get(Oas.Trainings.TrainingWhere, id)
          _ -> %Oas.Trainings.TrainingWhere{}
        end
        |> Ecto.Changeset.cast(args, [:name, :credit_amount])
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
