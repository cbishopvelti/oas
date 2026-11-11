defmodule Oas.Repo.Migrations.BankCountry do
  use Ecto.Migration

  # Two-letter ISO country code used to list banks in the GoCardless
  # requisition flow. Existing rows get "GB".
  def change do
    alter table(:config_config) do
      add :bank_country, :string, null: false, default: "GB"
    end
  end
end
