defmodule Oas.Repo.Migrations.DropTransactionsTrainingWheres do
  use Ecto.Migration

  # transactions_training_wheres was created in 20260222180917_venue_billing
  # but no schema or query ever used it.
  def up do
    drop_if_exists index(:transactions_training_wheres, [:transaction_id, :training_where_id])
    drop_if_exists table(:transactions_training_wheres)
  end

  def down do
    create table(:transactions_training_wheres) do
      add :transaction_id, references(:transactions, on_delete: :restrict)
      add :training_where_id, references(:training_where, on_delete: :delete_all)
    end

    create unique_index(:transactions_training_wheres, [:transaction_id, :training_where_id])
  end
end
