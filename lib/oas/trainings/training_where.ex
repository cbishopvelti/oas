defmodule Oas.Trainings.TrainingWhere do
  use Ecto.Schema
  import Ecto.Changeset

  schema "training_where" do
    field :name, :string
    field :credit_amount, :decimal
    field :limit, :integer

    has_many :trainings, Oas.Trainings.Training, foreign_key: :training_where_id

    has_many :training_where_time, Oas.Trainings.TrainingWhereTime,
      foreign_key: :training_where_id

    has_many :training_deleted, Oas.Trainings.TrainingDeleted, foreign_key: :training_where_id
    has_many :receivables, Oas.Trainings.TrainingWhereReceivable, foreign_key: :training_where_id

    timestamps()
  end

  defp validate_credit_amount(changeset) do
    cond do
      Decimal.to_float(get_field(changeset, :credit_amount)) < 0 ->
        add_error(changeset, :credit_amount, "Amount must be positive.")

      true ->
        changeset
    end
  end

  def changeset(changeset, params \\ %{}) do
    changeset
    |> Ecto.Changeset.cast(params, [:name, :credit_amount, :limit])
    |> validate_credit_amount
  end
end
