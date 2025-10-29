defmodule Oas.Repo.Migrations.Booking2 do
  use Ecto.Migration

  def change do
    alter table(:trainings) do
      add :commitment, :boolean, null: true
    end
  end
end
