defmodule Oas.Natwest.Config do
  use Ecto.Schema

  schema "config_natwest" do
    field :client_id, :string
    field :client_secret, :string
    field :consent_access_token, :string
    field :access_token, :string
    field :refresh_token, :string
    field :id_token, :string
    field :account_id, :string
    timestamps()
  end
end
