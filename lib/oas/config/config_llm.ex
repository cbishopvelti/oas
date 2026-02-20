defmodule Oas.Config.ConfigLlm do
  use Ecto.Schema

  schema "config_llm" do
    field :chat_enabled, :boolean
    field :llm_enabled, :boolean
    field :context, :string
    timestamps()
  end
end
