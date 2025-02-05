defmodule Oas.Config.Tokens do
  use Ecto.Schema

  schema "config_tokens" do
    field :quantity, :integer
    field :value, :decimal
    timestamps()
  end
end
