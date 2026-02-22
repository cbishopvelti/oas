defmodule Oas.Llm.ChatMembers do
  use Ecto.Schema

  schema "chats_members" do
    field :order_joined, :integer

    belongs_to :member, Oas.Members.Member
    belongs_to :chat, Oas.Llm.Chat

    timestamps()
  end
end
