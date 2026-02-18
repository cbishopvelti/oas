defmodule Oas.Repo.Migrations.TrainingWhereTimeAmount do
  use Ecto.Migration

  def change do
    alter table(:training_where_time) do
      add :credit_amount, :decimal, null: true
    end
  end
end
