defmodule Oas.Repo.Migrations.GocardlessEnabled do
  use Ecto.Migration

  def change do
    alter table(:config_config) do
      add :gocardless_enabled, :boolean, null: true
    end
  end
end
