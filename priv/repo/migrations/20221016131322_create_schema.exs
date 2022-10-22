defmodule Oas.Repo.Migrations.CreateSchema do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :what, :string, null: false
      add :when, :date, null: false
      add :who_member_id, references(:members, on_delete: :restrict), null: true
      add :who, :string, null: true
      add :type, :string, null: false
      add :amount, :decimal, null: false
      add :notes, :string
      add :bank_details, :string
      timestamps()
    end

    create table(:membership) do
      add :transaction_id, references(:transactions, on_delete: :restrict), null: true
      add :member_id, references(:members, on_delete: :restrict), null: false
      add :expires_on, :date, null: true
      add :notes, :string
      timestamps()
    end

    create table(:trainings) do
      add :when, :date, null: false
      add :where, :string
      timestamps()
    end

    create table(:attendance) do
      add :training_id, references(:trainings, on_delete: :restrict), null: false
      add :member_id, references(:members, on_delete: :restrict), null: false
      timestamps()
    end

    create table(:tokens) do
      add :transaction_id, references(:transactions, on_delete: :restrict), null: true, on_delete: :restrict
      add :member_id, references(:members, on_delete: :restrict), null: false
      add :used_on, :date, null: true
      add :expires_on, :date, null: false
      add :attendance_id, references(:attendance, on_delete: :restrict), null: true
      add :value, :decimal, null: false
      timestamps()
    end
  end
end
