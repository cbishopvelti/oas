defmodule Oas.Repo.Migrations.CreateSchema do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :what, :string, null: false
      add :when, :date, null: false
      add :who_member_id, :id, null: true, references: :members
      add :who, :string, null: true
      add :type, :string, null: false
      add :amount, :decimal
      add :notes, :string
      add :bank_details, :string
      timestamps()
    end

    create table(:membership) do
      add :transaction_id, :id, null: true, references: :transactions
      add :member_id, :id, null: false, references: :members
      add :expires_on, :date
      add :notes, :string
      timestamps()
    end

    create table(:trainings) do
      add :when, :date
      add :where, :string
      timestamps()
    end

    create table(:attendance) do
      add :training_id, :id, references: :tranings
      add :member_id, :id, references: :member
      timestamps()
    end

    create table(:tokens) do
      add :transaction_id, :id, references: :transactions, null: true
      add :member_id, :id, references: :members, null: false
      add :used_on, :date, null: true
      add :expires_on, :date, null: false
      add :attendance_id, :id, references: :attendance, null: true
      add :value, :decimal, null: false
      timestamps()
    end
  end
end
