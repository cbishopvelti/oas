import Ecto.Query, only: [from: 2]

defmodule Oas.Trainings.TrainingWhere do
  use Ecto.Schema
  import Ecto.Changeset

  schema "training_where" do
    field :name, :string
    field :credit_amount, :decimal
    field :limit, :integer

    field :billing_type, Ecto.Enum, values: [:per_hour, :per_attendee, :fixed]
    field :billing_config, :map
    belongs_to :gocardless, Oas.Gocardless.GocardlessEcto
    has_many :transactions, Oas.Transactions.Transaction

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
    |> Ecto.Changeset.cast(params, [:name, :credit_amount, :limit,
      :billing_type, :billing_config],
      empty_values:  [[], nil, %{}] ++ Ecto.Changeset.empty_values()
    )
    |> Ecto.Changeset.cast_assoc(:gocardless, with: &Oas.Gocardless.GocardlessEcto.changeset/2)
    |> validate_credit_amount
    |> validate_and_set_billing_config
    |> validate_per_hour
  end

  def get_billing_for_training(%{venue_billing_type: nil}) do
    Decimal.new("0")
  end
  def get_billing_for_training(%{venue_billing_type: :per_hour} = training) do
    hours = (Time.diff(training.end_time,  training.start_time, :minute) / 60)
      |> Decimal.from_float()

    training.venue_billing_config["per_hour"]
    |> Decimal.mult(hours)
  end
  def get_billing_for_training(%{venue_billing_type: :per_attendee} = training) do
    training.venue_billing_config["per_attendee"]
    |> Decimal.mult(training.attendance |> length())
  end
  def get_billing_for_training(%{venue_billing_type: :fixed} = training) do
    training.venue_billing_config["fixed"]
  end

  # Oas.Trainings.TrainingWhere.get_account_liability(2)
  def get_account_liability(id) do

    trainings = from(trai in Oas.Trainings.Training,
      preload: [:attendance, :training_where],
      where: trai.training_where_id == ^id and not is_nil(trai.venue_billing_type),
      order_by: [asc: trai.when]
    )
    |> Oas.Repo.all()


    transactions = from(tran in Oas.Transactions.Transaction,
      where: tran.training_where_id == ^id,
      order_by: [asc: tran.when]
    ) |> Oas.Repo.all()

    both = (trainings ++ transactions)
    |> Enum.sort_by(fn %{when: when1} -> when1 end, :asc)

    out = both |> Enum.reduce({Decimal.new("0"), []}, fn %Oas.Transactions.Transaction{} = trans, {total, rows} ->
        amount = trans.amount |> Decimal.mult("-1")
        acc_amount = Decimal.add(amount, total)
        {acc_amount, [{acc_amount, amount, %{
          what: trans.what,
          when: trans.when,
          transaction_id: trans.id
        }}]}
      %Oas.Trainings.Training{} = trai, {total, rows} ->
        amount = get_billing_for_training(trai)
        acc_amount = Decimal.add(total, amount)
        {acc_amount, [{acc_amount, amount, %{
          what: trai.training_where.name,
          when: trai.when,
          training_id: trai.id
        }} | rows]}
    end)

    out
  end
end
