defmodule Oas.Repo.Migrations.ConfigBacs do
  use Ecto.Migration

  def change do
    alter table(:config_config) do
      add :bacs, :string, null: true
    end
  end
end
