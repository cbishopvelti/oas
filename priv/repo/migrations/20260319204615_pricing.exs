defmodule Oas.Repo.Migrations.Pricing do
  use Ecto.Migration

  def change do

    create table(:pricings) do
      add :name, :string, null: false
      add :blockly_conf, :map, null: true, default: nil
      timestamps()
    end
    create unique_index(:pricings, [:name])

    create table(:pricing_instances) do
      add :is_active, :boolean, default: false
      add :name, :string, null: false
      add :blockly_conf, :map, null: true, default: nil
      add :blockly_lua, :string, null: true
      add :pricing_id, references(:pricings, on_delete: :restrict), null: false
      timestamps()
    end
    create unique_index(:pricing_instances, [:name])

    alter table(:trainings) do
      add :is_active, :boolean, default: true
      add :pricing_instance_id, references(:pricing_instances, on_delete: :nilify_all), null: true
    end

    execute "UPDATE trainings SET is_active = true", "SELECT 1"
  end
end
