defmodule :"Elixir.Oas.Repo.Migrations.Add-backup-recipient" do
  use Ecto.Migration

  def change do

    alter table(:config_config) do
      add :backup_recipient, :string, null: true
    end
  end
end
