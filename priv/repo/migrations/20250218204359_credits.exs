defmodule Oas.Repo.Migrations.Credits do
  use Ecto.Migration

  def change do
    create table(:things) do
      add :what, :string, null: false
      add :value, :decimal, null: true
      add :when, :date, null: false

      timestamps()
    end

    create table(:credits) do
      add :what, :string, null: false
      add :amount, :decimal, null: false
      add :when, :date, null: false
      add :who_member_id, references(:members, on_delete: :restrict), null: false
      add :transaction_id, references(:transactions, on_delete: :delete_all), null: true
      add :attendance_id, references(:attendance, on_delete: :delete_all), null: true
      add :membership_id, references(:memberships, on_delete: :delete_all), null: true
      add :credit_id, references(:credits, on_delete: :delete_all), null: true
      add :thing_id, references(:things, on_delete: :restrict), null: true
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
      add :content, :string, null: true
    end

    alter table(:training_where) do
      add :credit_amount, :decimal, null: true
    end

    alter table(:members) do
      add :honorary_member, :boolean, null: true
    end
  end
end
