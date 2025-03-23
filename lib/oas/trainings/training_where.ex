defmodule Oas.Trainings.TrainingWhere do
  use Ecto.Schema

  schema "training_where" do
    field :name, :string
    field :credit_amount, :decimal
    field :time, :time
    field :cutoff_booking, Oas.Trainings.MyDuration
    field :cutoff_queue, :string
    field :max_attendees, :integer

    has_many :trainings, Oas.Trainings.Training, foreign_key: :training_where_id

    timestamps()
  end
end
