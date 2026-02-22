defmodule Oas.Repo.Migrations.TrainingWhereTime do
  use Ecto.Migration

  def change do
    create table(:training_where_time) do
      add :training_where_id, references(:training_where, on_delete: :delete_all), null: false
      add :day_of_week, :integer, null: true
      add :start_time, :time, null: true
      add :end_time, :time, null: true
      add :booking_offset, :text, null: true
      add :recurring, :boolean, null: true

      timestamps()
    end

    create table(:training_deleted) do
      add :training_where_id, references(:training_where, on_delete: :delete_all), null: false
      add :when, :date, null: false

      timestamps()
    end

    alter table(:trainings) do
      add :start_time, :time, null: true
      add :end_time, :time, null: true
      add :booking_offset, :text, null: true
    end

    create unique_index(:training_where_time, [:day_of_week, :training_where_id])
  end
end
