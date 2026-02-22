defmodule Oas.Llm.ChatSeen do
  use Ecto.Schema

  schema "chat_seen" do
    belongs_to :member, Oas.Members.Member
    belongs_to :chat, Oas.Llm.Chat

    timestamps()
  end
end
