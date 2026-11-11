defmodule Oas.Repo.Migrations.CreateConfigTokens do
  use Ecto.Migration

  def up do
    create table(:config_tokens) do
      add :value, :decimal, null: false
      add :quantity, :integer, null: false
      add :expiry_days, :integer, null: true
      timestamps()
    end

    create table(:config_config) do
      add :token_expiry_days, :integer, null: true
      timestamps()
    end

    flush()

    # Plain SQL rather than the Ecto schemas: the schemas describe today's
    # tables, which have columns this migration has not created yet.
    execute("""
    INSERT INTO config_tokens (value, quantity, inserted_at, updated_at) VALUES
      (5, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
      (4.5, 10, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
      (4.5, 20, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    """)

    # The single config_config row is inserted by
    # 20261111120000_seed_config_rows.exs, once every column exists.
  end

  def down do
    drop table(:config_tokens)
    drop table(:config_config)
  end
end
