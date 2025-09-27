defmodule Oas.Repo.Migrations.Truelayer do
  use Ecto.Migration

  def up do
    create table(:config_truelayer) do
      add :client_id, :string, null: true
      add :client_secret, :string, null: true
      add :access_token, :string, null: true
      add :refresh_token, :string, null: true
      add :account_id, :string, null: true
      timestamps()
    end

    flush()

    Oas.Repo.insert(%Oas.Truelayer.Config{
      client_id: "oas1-9c7b5d",
      client_secret: "ae2b064f-14b4-4fa6-b288-04dc94d7069a"
    })

  end

  def down do
    drop table(:config_truelayer)
  end
end
