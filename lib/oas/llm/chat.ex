import Ecto.Query, only: [from: 2]

defmodule Oas.Llm.Chat do
  use Ecto.Schema

  schema "chats" do
    field :topic, :string
    field :chat, :string

    many_to_many :members, Oas.Members.Member, join_through: Oas.Llm.ChatMembers
    has_many :chat_members, Oas.Llm.ChatMembers
    timestamps()
  end
end
