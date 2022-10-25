defmodule Oas.Trainings.TrainingTags do
  use Ecto.Schema
  import Ecto.Changeset

  schema "training_tags" do
    field :name, :string
    timestamps()
  end

  def changeset(struct, params) do
    IO.puts("102 training_tags.chasget")
    struct
    |> Ecto.Changeset.cast(params, [:name])
  end
end