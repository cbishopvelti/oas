import Ecto.Query, only: [from: 2]

defmodule Oas.Trainings.TrainingWhere do
  use Ecto.Schema
  import Ecto.Changeset

  schema "training_where" do
    field :name, :string
    field :credit_amount, :decimal

    field :billing_type, Ecto.Enum, values: [:per_hour, :per_attendee, :fixed]
    field :billing_config, :map
    belongs_to :gocardless, Oas.Gocardless.GocardlessEcto

    has_many :trainings, Oas.Trainings.Training, foreign_key: :training_where_id
    has_many :training_where_time, Oas.Trainings.TrainingWhereTime, foreign_key: :training_where_id
    has_many :training_deleted, Oas.Trainings.TrainingDeleted, foreign_key: :training_where_id

    timestamps()
  end

  defp validate_credit_amount (changeset) do
    cond do
      Decimal.to_float(get_field(changeset, :credit_amount)) < 0 -> add_error(changeset, :credit_amount, "Amount must be positive.")
      true -> changeset
    end
  end

  defp validate_and_set_billing_config(changeset) do
    type = get_field(changeset, :billing_type)
    config = get_field(changeset, :billing_config) || %{}

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
          put_change(changeset, :billing_config, new_config)
        :missing ->
          add_error(changeset, :billing_config, "#{key_to_validate} rate must be set")

        :invalid ->
          add_error(changeset, :billing_config, "#{key_to_validate} must be a valid number")
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

  defp validate_per_hour(changeset) do
    case get_field(changeset, :billing_type) do
      :per_hour ->
        case Ecto.Changeset.get_field(changeset, :id) do
          nil -> changeset
          id -> case from(t in Oas.Trainings.TrainingWhereTime,
            where: t.training_where_id == ^id and (is_nil(t.start_time) or is_nil(t.end_time) )
          ) |> Oas.Repo.exists?() do
            true -> changeset |> add_error(:billing_type, "start_time and end_time must be set on all Times")
            false -> changeset
          end
        end
      _ -> changeset
    end
  end

  def changeset(changeset, params \\ %{}) do
    changeset
    |> Ecto.Changeset.cast(params, [:name, :credit_amount,
      :billing_type, :billing_config],
      empty_values:  [[], nil, %{}] ++ Ecto.Changeset.empty_values()
    )
    |> Ecto.Changeset.cast_assoc(:gocardless, with: &Oas.Gocardless.GocardlessEcto.changeset/2)
    |> validate_credit_amount
    |> validate_and_set_billing_config
    |> validate_per_hour
  end

  @deprecated "remove"
  def get_billing_amount(%{
    training_where: training_where,
    training: training,
    start_time: _start_time,
    end_time: _end_time
  }) do
    case training_where.billing_type do
      nil -> ""
      :per_hour ->
        # training_where.billing_config
        "todo"
      :per_attendee ->

        case training do
          nil -> ""
          training ->
            per_attendee = training_where.billing_config["per_attendee"] |> Decimal.new()
            attendance = training.attendance |> Enum.count()

            Decimal.mult(per_attendee, attendance) |> Decimal.to_string()
        end
    end

  end
end
