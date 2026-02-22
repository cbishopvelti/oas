defmodule Oas.Repo.Migrations.CreateTrainingWhereReceivables do
  use Ecto.Migration

  def change do
    create table(:training_where_receivables) do
      add :amount, :decimal
      add :description, :string
      add :expected_return_date, :date
      add :status, :string, default: "HELD"

      add :training_where_id, references(:training_where, on_delete: :nothing)
      add :sent_transaction_id, references(:transactions, on_delete: :nothing)
      add :returned_transaction_id, references(:transactions, on_delete: :nothing)

      timestamps()
    end

    create index(:training_where_receivables, [:training_where_id])
    create index(:training_where_receivables, [:sent_transaction_id])
    create index(:training_where_receivables, [:returned_transaction_id])
  end
end
