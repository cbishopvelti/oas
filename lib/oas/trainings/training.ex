defmodule Oas.Trainings.Training do
  use Ecto.Schema

  schema "trainings" do
    belongs_to :training_where, Oas.Trainings.TrainingWhere, on_replace: :nilify
    field :when, :date
    field :commitment, :boolean
    field :start_time, :time
    field :booking_offset, :string
    field :end_time, :time
    field :limit, :integer
    field :exempt_membership_count, :boolean
    field :disable_warning_emails, :boolean

    has_many :attendance, Oas.Trainings.Attendance

    many_to_many :training_tags, Oas.Trainings.TrainingTags,
      join_through: "training_training_tags",
      join_keys: [training_id: :id, training_tag_id: :id],
      on_replace: :delete

    field :notes, :string

    timestamps()
  end

  def validate_time(changeset) do
    case Ecto.Changeset.get_field(changeset, :booking_offset) do
      nil ->
        changeset

      duration ->
        changeset = Ecto.Changeset.validate_required(changeset, :start_time)

        case Duration.from_iso8601(duration) do
          {:ok, _} ->
            changeset

          {:error, error} ->
            Ecto.Changeset.add_error(changeset, :booking_offset, error |> to_string())
        end
    end
  end
end
