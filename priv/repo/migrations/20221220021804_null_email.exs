defmodule Oas.Repo.Migrations.NullEmail do
  use Ecto.Migration

  def up do
    # alter table(:members) do
    #   modify :email, :string, null: true
    # end

    execute "PRAGMA foreign_keys=OFF"
    execute "PRAGMA legacy_alter_table = ON"
    result = repo().query! "PRAGMA foreign_keys" # This should return 0, it returns 1 :(
    IO.inspect(result)
    
    rename table(:members), to: table(:members_tmp6)

    create table(:members) do
      add :email, :string, null: true, collate: :nocase
      add :name, :string, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
      add :is_admin, :boolean
      add :is_reviewer, :boolean
      add :is_active, :boolean # Can they use the site
      add :bank_account_name, :string, null: true

      timestamps()
    end
    
    execute("INSERT INTO members SELECT * FROM members_tmp6")

    execute "PRAGMA foreign_keys=ON"
    execute "PRAGMA legacy_alter_table=OFF"

    drop table(:members_tmp6)
  end
  def down do
    
  end
end
