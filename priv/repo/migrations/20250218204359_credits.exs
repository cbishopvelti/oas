defmodule Oas.Repo.Migrations.Credits do
  use Ecto.Migration

  def change do
    create table(:credits) do
      add :what, :string, null: false
      add :amount, :decimal, null: false
      add :when, :date, null: false
      add :who_member_id, references(:members, on_delete: :restrict), null: false
      add :transaction_id, references(:transactions, on_delete: :restrict), null: true
      add :expires_on, :date, null: true
      timestamps()
    end

    create table(:credits_credits) do
      add :used_for_id, references(:credits), null: false
      add :uses_id, references(:credits), null: false
      add :amount, :decimal, null: false
      # add :amount, :decimal, null: false
      # timestamps()
    end

    create unique_index(:credits_credits, [:used_for_id, :uses_id])

    alter table(:config_config) do
      add :credits, :boolean, default: false
    end

    alter table(:training_where) do
      add :credit_amount, :decimal, null: true
    end
  end
end
