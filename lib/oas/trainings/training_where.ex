defmodule Oas.Trainings.TrainingWhere do
  use Ecto.Schema

  schema "training_where" do
    field :name, :string

    timestamps()
  end
end
