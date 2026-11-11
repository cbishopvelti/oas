defmodule Oas.Repo.Migrations.SeedConfigRows do
  use Ecto.Migration

  # The app expects exactly one row in config_config and in config_llm
  # (Oas.Settings.get_config!/0 and get_llm!/0 raise on an empty table).
  # Insert a default row into each table only when it is empty, so a brand new
  # database starts cleanly. An existing row is never touched.
  #
  # config_tokens is left alone: an empty price list is a valid admin choice,
  # and 20221202213706_create_config_tokens.exs already seeds it on a new
  # database.

  def up do
    execute("""
    INSERT INTO config_config (name, token_expiry_days, inserted_at, updated_at)
    SELECT 'Society', 365, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    WHERE NOT EXISTS (SELECT 1 FROM config_config)
    """)

    execute("""
    INSERT INTO config_llm (chat_enabled, context, inserted_at, updated_at)
    SELECT false, '', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    WHERE NOT EXISTS (SELECT 1 FROM config_llm)
    """)
  end

  # Nothing to undo: the rows may have been edited since, and an existing
  # database never got a row from this migration.
  def down, do: :ok
end
