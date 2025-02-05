defmodule Oas.Repo.Migrations.Gocardless do
  use Ecto.Migration

  def change do
    alter table(:config_config) do
      add :gocardless_id, :string, null: true
      add :gocardless_key, :string, null: true
      add :gocardless_requisition_id, :string, null: true
      add :gocardless_account_id, :string, null: true
    end
  end
end
