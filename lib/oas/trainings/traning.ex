defmodule Oas.Trainings.Training do
  use Ecto.Schema
  import Ecto.Changeset

  schema "trainings" do
    field :where, :string
    field :when, :date
    has_many :attendance, Oas.Trainings.Attendance
    many_to_many :training_tags, Oas.Trainings.TrainingTags,
      join_through: "training_training_tags", join_keys: [training_id: :id, training_tag_id: :id]

    timestamps()
  end
end