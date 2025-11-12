defmodule Oas.Config.ConfigLlm do
  use Ecto.Schema

  schema "config_llm" do
    field :context, :string
    timestamps()
  end
end
