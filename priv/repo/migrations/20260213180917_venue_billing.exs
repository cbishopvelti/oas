defmodule Oas.Repo.Migrations.VenueBilling do
  use Ecto.Migration

  def change do
    alter table(:training_where) do
      add :billing_type, :string, null: true
      add :billing_config, :map, null: true
      add :gocardless_name, :string, null: true
    end

    alter table(:trainings) do
      add :venue_billing_enabled, :boolean, null: true
      add :venue_billing_override, :decimal, null: true
    end

    create table(:transactions_training_wheres) do
      add :transaction_id, references(:transactions, on_delete: :restrict)
      add :training_where_id, references(:training_where, on_delete: :delete_all)
    end
    create unique_index(:transactions_training_wheres, [:transaction_id, :training_where_id])
  end
end
