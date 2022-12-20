defmodule Oas.Repo.Migrations.NullEmail do
  use Ecto.Migration

  def up do
    alter table(:members) do
      modify :email, :string, null: true
    end

    
    # result = repo().query! "PRAGMA foreign_keys" # This should return 0, it returns 1 :(
    # IO.inspect(result)

    # alter table(:transactions) do
    #   add :who_member_id, references(:members, on_delete: :restrict), null: true
      
    # end
    # drop constraint(:transaction, references(:members, on_delete: :restrict))
    
    # rename table(:members), to: table(:members_tmp6)

    # create table(:members) do
    #   add :email, :string, null: true, collate: :nocase
    #   add :name, :string, null: false
    #   add :hashed_password, :string, null: false
    #   add :confirmed_at, :naive_datetime
    #   add :is_admin, :boolean
    #   add :is_reviewer, :boolean
    #   add :is_active, :boolean # Can they use the site
    #   add :bank_account_name, :string, null: true

    #   timestamps()
    # end
    
    # execute("INSERT INTO members SELECT * FROM members_tmp6")


    # drop table(:members_tmp6)
  end
  def down do
    
  end
end
