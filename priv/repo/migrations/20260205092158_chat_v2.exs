defmodule Oas.Repo.Migrations.ChatV2 do
  use Ecto.Migration

  def change do
    alter table(:config_llm) do
      add :llm_enabled, :boolean, default: false
    end

    create table(:chat_seen) do
      add :member_id, references(:members, on_delete: :delete_all), null: false
      add :chat_id, references(:chats, on_delete: :delete_all), null: false
      timestamps()
    end

    create unique_index(:chat_seen, [:member_id, :chat_id])
  end
end
