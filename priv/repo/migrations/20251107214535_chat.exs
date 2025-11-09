defmodule Oas.Repo.Migrations.Chat do
  use Ecto.Migration

  def change do
    create table(:chats) do
      add :topic, :string, null: true
      add :chat, :string, null: true
      timestamps()
    end
    create unique_index(:chats, :topic)

    create table(:chats_members) do
      add :member_id, references(:members), null: false
      add :chat_id, references(:chats, on_delete: :delete_all), null: false

      timestamps()
    end
    create unique_index(:chats_members, [:member_id, :chat_id])
  end
end
