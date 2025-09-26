defmodule Oas.Repo.Migrations.Plaid do
  use Ecto.Migration

  def change do

    create table(:config_plaid) do
      add :url, :string, null: true
      add :client_id, :string, null: true
      add :secret, :string, null: true
      add :item_id, :string, null: true
      add :access_token, :string, null: true
      add :account_id, :string, null: true
      timestamps()
    end

    flush()

    Oas.Repo.insert(%Oas.Plaid.Config{
      url: "https://sandbox.plaid.com"
    });
  end
end
