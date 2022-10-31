defmodule Oas.Repo.Migrations.CreateSchema do
  use Ecto.Migration

  def change do
    # Transactions
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

    create table(:transaction_tags) do
      add :name, :string
      timestamps()
    end

    create table(:transaction_transaction_tags) do
      add :transaction_tag_id, references(:transaction_tags, on_delete: :delete_all)
      add :transaction_id, references(:transactions, on_delete: :delete_all)
    end

    # EO Transactions

    # Membership

    create table(:membership_periods) do
      add :name, :string, null: false
      add :from, :date, null: false
      add :to, :date, null: false
      add :value, :decimal, null: false

      timestamps()
    end

    create table(:memberships) do
      add :transaction_id, references(:transactions, on_delete: :restrict), null: true
      add :member_id, references(:members, on_delete: :restrict), null: false
      add :membership_period_id, references(:membership_periods, on_delete: :restrict), null: false

      add :notes, :string, null: true
      timestamps()
    end


    # EO Membership

    # TRAININGS
    create table(:training_where) do
      add :name, :string

      timestamps()
    end
    create unique_index(:training_where, [:name])

    create table(:trainings) do
      add :when, :date, null: false
      add :training_where_id, references(
        :training_where,
        on_delete: :restrict
      ), null: false
      timestamps()
    end

    create table(:training_tags) do
      add :name, :string

      timestamps()
    end

    create table(:training_training_tags) do
      add :training_tag_id, references(:training_tags, on_delete: :delete_all)
      add :training_id, references(:trainings, on_delete: :delete_all)
    end

    create table(:attendance) do
      add :training_id, references(:trainings, on_delete: :restrict), null: false
      add :member_id, references(:members, on_delete: :restrict), null: false
      timestamps()
    end
    # EO TRANINGS  

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
