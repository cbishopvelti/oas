defmodule Oas.Trainings.TrainingWhere do
  use Ecto.Schema
  import Ecto.Changeset

  schema "training_where" do
    field :name, :string

    timestamps()
  end
end