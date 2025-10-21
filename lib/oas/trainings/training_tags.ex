defmodule Oas.Trainings.TrainingTags do
  use Ecto.Schema

  schema "training_tags" do
    field :name, :string
    timestamps()
  end

  def changeset(struct, params) do
    struct
    |> Ecto.Changeset.cast(params, [:name])
  end
end
