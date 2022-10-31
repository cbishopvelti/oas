defmodule Oas.Repo.Migrations.CreateMembersAuthTables do
  use Ecto.Migration

  def change do
    create table(:members) do
      add :email, :string, null: false, collate: :nocase
      add :name, :string, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
      add :is_admin, :boolean
      add :is_reviewer, :boolean
      add :is_active, :boolean # Can they use the site
      add :bank_reference, :string, null: true
      add :bank_account_name, :string, null: true

      timestamps()
    end
    create unique_index(:members, [:email])

    create table(:members_details) do
      
      add :phone, :string, null: false
      add :address, :string, null: false
      add :dob, :date, null: false
      add :agreed_to_tac, :boolean, null: false

      add :nok_name, :string, null: false
      add :nok_email, :string, null: false
      add :nok_phone, :string, null: false
      add :nok_address, :string, null: false
      
      add :member_id, references(:members, on_delete: :delete_all), null: false

      timestamps()
    end

    create table(:members_tokens) do
      add :member_id, references(:members, on_delete: :delete_all), null: false
      add :token, :binary, null: false, size: 32
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end
    

    create index(:members_tokens, [:member_id])
    create unique_index(:members_tokens, [:context, :token])
  end
end
