defmodule Oas.Trainings.TrainingDeleted do
  use Ecto.Schema

  schema "training_deleted" do
    belongs_to :training_where, Oas.Trainings.TrainingWhere
    field :when, :date

    timestamps()
  end
end
