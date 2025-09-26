defmodule Oas.Plaid.Config do
  use Ecto.Schema

  schema "config_plaid" do
    field :url, :string
    field :client_id, :string
    field :secret, :string
    field :item_id, :string
    field :access_token, :string
    field :account_id, :string

    timestamps()
  end
end
