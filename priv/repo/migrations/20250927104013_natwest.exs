defmodule Oas.Repo.Migrations.Natwest do
  use Ecto.Migration

  def up do
    create table(:config_natwest) do
      add :consent_access_token, :string, null: true
      add :client_id, :string, null: true
      add :client_secret, :string, null: true
      add :access_token, :string, null: true
      add :refresh_token, :string, null: true
      add :id_token, :string, null: true
      add :account_id, :string, null: true

      timestamps()
    end

    flush()

    Oas.Repo.insert(%Oas.Natwest.Config{
      client_id: "Tx4l5sOg0pW8cAL0FFHRo70qBSPskInpRoLSXv0nCVQ=",
      client_secret: "ezKm6kGxtK40PbdK25fZ9LPsFcaVQ2m_B8ccLa6PvOc="
    })

  end

  def down do
    drop table(:config_natwest)
  end
end
