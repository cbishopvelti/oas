defmodule Oas.Trainings.Training do
  use Ecto.Schema
  import Ecto.Changeset

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

    field :venue_billing_type, Ecto.Enum, values: [:per_hour, :per_attendee, :fixed]
    field :venue_billing_config, :map

    has_many :attendance, Oas.Trainings.Attendance
    many_to_many :training_tags, Oas.Trainings.TrainingTags,
      join_through: "training_training_tags", join_keys: [training_id: :id, training_tag_id: :id], on_replace: :delete
    field :notes, :string

    timestamps()
  end

  def validate_time(changeset) do
    case Ecto.Changeset.get_field(changeset, :booking_offset) do
      nil -> changeset
      duration ->
        changeset = Ecto.Changeset.validate_required(changeset, :start_time)
        case Duration.from_iso8601(duration) do
          {:ok, _} -> changeset
          {:error, error} -> Ecto.Changeset.add_error(changeset, :booking_offset, error |> to_string())
        end
    end
  end

  def validate_billing(changeset) do
    changeset
    |> validate_billing_config()
    |> validate_billing_time()
  end

  defp validate_billing_time(changeset) do
    type = get_field(changeset, :venue_billing_type)
    case type do
      :per_hour ->
        case get_field(changeset, :start_time) do
          nil -> add_error(changeset, :start_time, "start_time must be set if per hour billing in enabled")
          _ -> changeset
        end
        |> then(fn changeset ->
          case get_field(changeset, :end_time) do
            nil -> add_error(changeset, :end_time, "end_time must be set if per hour billing is active")
            _ -> changeset
          end
        end)
      _ -> changeset
    end
  end

  defp validate_billing_config(changeset) do
    type = get_field(changeset, :venue_billing_type)
    config = get_field(changeset, :venue_billing_config) || %{}

    key_to_validate =
      case type do
        :per_attendee -> :per_attendee
        :per_hour -> :per_hour
        _ -> nil
      end

    if key_to_validate do
      raw_value = Map.get(config, key_to_validate) || Map.get(config, to_string(key_to_validate))

      case cast_to_decimal(raw_value) do
        {:ok, valid_decimal} ->
          new_config = Map.put(config, to_string(key_to_validate), valid_decimal)
          put_change(changeset, :venue_billing_config, new_config)
        :missing ->
          add_error(changeset, :venue_billing_config, "#{key_to_validate} rate must be set")

        :invalid ->
          add_error(changeset, :venue_billing_config, "#{key_to_validate} must be a valid number")
      end
    else
      changeset
    end
  end

  defp cast_to_decimal(nil), do: :missing
  defp cast_to_decimal(""), do: :missing
  defp cast_to_decimal(val) do
    case Decimal.cast(val) do
      {:ok, decimal} -> {:ok, decimal}
      :error -> :invalid
    end
  end
end
