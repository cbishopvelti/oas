defmodule Oas.Repo.Migrations.ConfigBooking do
  use Ecto.Migration

  def change do
    alter table(:config_config) do
      add :enable_booking, :boolean, null: false, default: false
    end
  end
end
