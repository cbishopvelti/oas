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

    Oas.Repo.insert(%Oas.Config.Tokens{
      value: 5,
      quantity: 1
    });
    Oas.Repo.insert(%Oas.Config.Tokens{
      value: 4.5,
      quantity: 10
    });
    Oas.Repo.insert(%Oas.Config.Tokens{
      value: 4.5,
      quantity: 20
    });

    Oas.Repo.insert(%Oas.Config.Config{
      token_expiry_days: 365
    });
  end

  def down do
    drop table(:config_tokens)
    drop table(:config_config)
  end
end
