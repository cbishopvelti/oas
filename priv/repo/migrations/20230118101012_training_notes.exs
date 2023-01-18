defmodule Oas.Repo.Migrations.TrainingNotes do
  use Ecto.Migration

  def change do
    alter table(:trainings) do
      add :notes, :string, null: true
    end

    alter table(:config_config) do
      add :name, :string, null: true
    end
  end
end
