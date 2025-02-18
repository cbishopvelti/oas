defmodule Oas.Repo.Migrations.GocardlessTransactions do
  use Ecto.Migration

  def change do
    alter table(:members) do
      add :gocardless_name, :string, null: true
    end

    create table(:gocardless_transaction_iids) do
      add :transaction_iid, :string, null: false
      add :transaction_id, references(:transactions, on_delete: :nilify_all), null: true
      add :warnings, :text, null: true
      add :gocardless_data, :text, null: true
    end
    create unique_index(:gocardless_transaction_iids, [:transaction_iid])
    create unique_index(:gocardless_transaction_iids, [:transaction_id])

  end
end
