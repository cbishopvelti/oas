defmodule Oas.Trainings.Training do
  use Ecto.Schema

  schema "trainings" do
    belongs_to :training_where, Oas.Trainings.TrainingWhere, on_replace: :nilify
    field :when, :date
    field :commitment, :boolean
    has_many :attendance, Oas.Trainings.Attendance
    many_to_many :training_tags, Oas.Trainings.TrainingTags,
      join_through: "training_training_tags", join_keys: [training_id: :id, training_tag_id: :id], on_replace: :delete
    field :notes, :string

    timestamps()
  end
end
