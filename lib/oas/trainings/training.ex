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
    field :credit_amount, :decimal
    field :is_active, :boolean

    field :venue_billing_type, Ecto.Enum, values: [:per_hour, :per_attendee, :fixed]
    field :venue_billing_config, :map

    has_many :attendance, Oas.Trainings.Attendance
    many_to_many :training_tags, Oas.Trainings.TrainingTags,
      join_through: "training_training_tags", join_keys: [training_id: :id, training_tag_id: :id], on_replace: :delete
    field :notes, :string

    belongs_to :pricing_instance, Oas.Pricing.PricingInstance

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


  @doc "Assigns a pricing instance to a training with specific business rules."
  def assign_pricing_changeset(training, pricing_instance) do
    training
    |> change()
    |> put_change(:pricing_instance_id, pricing_instance.id)
    |> validate_active_states_match(pricing_instance)
    |> validate_no_existing_different_pricing()
  end

  # Rule 1: The is_active states must match
  defp validate_active_states_match(changeset, pricing_instance) do
    # get_field looks at the current struct data OR any pending changes
    training_active = get_field(changeset, :is_active)

    if training_active != pricing_instance.is_active do
      add_error(changeset, :pricing_instance_id, "is_active state must match the training's state")
    else
      changeset
    end
  end

  # Rule 2: Cannot overwrite an existing, different pricing instance
  defp validate_no_existing_different_pricing(changeset) do
    existing_id = changeset.data.pricing_instance_id
    new_id = get_change(changeset, :pricing_instance_id)

    # If the training already has an ID, and we are trying to change it to a NEW one, fail.
    # (If existing_id is nil, or if they are just passing the same ID again, it passes).
    if existing_id != nil and new_id != nil and existing_id != new_id do
      add_error(changeset, :pricing_instance_id, "training already has a different pricing instance assigned")
    else
      changeset
    end
  end
end
