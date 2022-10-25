defmodule Oas.Repo.Migrations.TrainingTags do
  use Ecto.Migration

  def change do

    create table(:training_tags) do
      add :name, :string

      timestamps()
    end

    create table(:training_training_tags) do
      add :training_tag_id, references(:training_tags, on_delete: :delete_all)
      add :training_id, references(:trainings, on_delete: :delete_all)
    end
  end
end
