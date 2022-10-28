defmodule Oas.Trainings.Training do
  use Ecto.Schema
  import Ecto.Changeset

  schema "trainings" do
    belongs_to :training_where, Oas.Trainings.TrainingWhere, on_replace: :nilify
    field :when, :date
    has_many :attendance, Oas.Trainings.Attendance
    many_to_many :training_tags, Oas.Trainings.TrainingTags,
      join_through: "training_training_tags", join_keys: [training_id: :id, training_tag_id: :id], on_replace: :delete

    timestamps()
  end
end