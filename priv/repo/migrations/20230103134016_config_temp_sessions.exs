defmodule Oas.Repo.Migrations.ConfigTempSessions do
  use Ecto.Migration

  def change do
    alter table(:config_config) do
      add :temporary_trainings, :integer, null: false, default: 3
    end
  end
end
