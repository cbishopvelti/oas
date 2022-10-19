defmodule Oas.Trainings.Training do
  use Ecto.Schema
  import Ecto.Changeset

  schema "trainings" do
    field :where, :string
    field :when, :date
    has_many :attendance, Oas.Trainings.Attendance

    timestamps()
  end
end