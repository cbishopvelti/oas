defmodule Oas.Repo.Migrations.TrainingWhereTimeAmount do
  use Ecto.Migration

  def change do

    alter table(:trainings) do
      add :limit, :integer, null: true
      add :exempt_membership_count, :boolean, null: true
    end

    alter table(:training_where) do
      add :limit, :integer, null: true
    end

    alter table(:training_where_time) do
      add :credit_amount, :decimal, null: true
      add :limit, :integer, null: true
    end
  end
end
