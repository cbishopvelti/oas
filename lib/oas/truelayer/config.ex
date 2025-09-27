defmodule Oas.Truelayer.Config do
  use Ecto.Schema

  schema "config_truelayer" do
    field :client_id, :string
    field :client_secret, :string
    field :access_token, :string
    field :refresh_token, :string
    field :account_id, :string
    timestamps()
  end
end
