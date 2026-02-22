defmodule Oas.Trainings.TrainingWhereReceivable do
  use Ecto.Schema
  import Ecto.Changeset

  schema "training_where_receivables" do
    field :amount, :decimal
    field :description, :string
    field :expected_return_date, :date
    field :status, Ecto.Enum, values: [:HELD, :RETURNED, :FORFEITED], default: :HELD

    belongs_to :training_where, Oas.Trainings.TrainingWhere
    belongs_to :sent_transaction, Oas.Transactions.Transaction
    belongs_to :returned_transaction, Oas.Transactions.Transaction

    timestamps()
  end

  def changeset(receivable, params \\ %{}) do
    receivable
    |> cast(params, [
      :amount,
      :description,
      :expected_return_date,
      :status,
      :training_where_id,
      :sent_transaction_id,
      :returned_transaction_id
    ])
    |> validate_required([:amount, :status, :training_where_id])
  end
end
