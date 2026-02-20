defmodule Oas.Repo.Migrations.VenueBilling do
  use Ecto.Migration

  defmodule Oas.Repo.Migrations.VenueBilling do
    use Ecto.Migration

    def up do
      # 1. Create the new table
      create table(:gocardless) do
        add :name, :string, null: false
        add :type, :string, null: false
        timestamps() # Assuming you want timestamps, otherwise remove
      end
      create unique_index(:gocardless, [:name])

      # 2. Add the foreign keys (nullable initially)
      alter table(:members) do
        add :gocardless_id, references(:gocardless, on_delete: :nilify_all)
      end
      create unique_index(:members, [:gocardless_id])

      alter table(:training_where) do
        add :billing_type, :string, null: true
        add :billing_config, :map, null: true, default: nil
        add :gocardless_id, references(:gocardless)
      end

      alter table(:trainings) do
        add :venue_billing_type, :string, null: true
        add :venue_billing_config, :map, null: true, default: nil
      end

      create table(:transactions_training_wheres) do
        add :transaction_id, references(:transactions, on_delete: :restrict)
        add :training_where_id, references(:training_where, on_delete: :delete_all)
      end
      create unique_index(:transactions_training_wheres, [:transaction_id, :training_where_id])

      # 3. DATA MIGRATION
      # We use flush() to ensure the schema changes above are committed before running SQL
      flush()

      # A. Insert unique names from members into the gocardless table
      execute """
      INSERT INTO gocardless (name, type, inserted_at, updated_at)
      SELECT DISTINCT gocardless_name, 'member', datetime('now'), datetime('now')
      FROM members
      WHERE gocardless_name IS NOT NULL;
      """

      # B. Update the members table to link to the new gocardless IDs
      execute """
      UPDATE members
      SET gocardless_id = gocardless.id
      FROM gocardless
      WHERE members.gocardless_name = gocardless.name;
      """

      # 4. Finally, remove the old column now that data is safe
      drop_if_exists index(:members, [:gocardless_name], name: "members_gocardless_name_index")
      alter table(:members) do
        remove :gocardless_name
      end
    end

    def down do
      # 1. Add the column back
      alter table(:members) do
        add :gocardless_name, :string
      end

      flush()

      # 2. Restore data from the relationship
      execute """
      UPDATE members
      SET gocardless_name = gocardless.name
      FROM gocardless
      WHERE members.gocardless_id = gocardless.id;
      """

      # 3. Drop new columns and tables
      drop table(:transactions_training_wheres)

      alter table(:trainings) do
        remove :venue_billing_type
        remove :venue_billing_config
      end

      alter table(:training_where) do
        remove :billing_type
        remove :billing_config
        remove :gocardless_id
      end

      drop_if_exists index(:members, [:gocardless_id])
      alter table(:members) do
        remove :gocardless_id
      end

      drop table(:gocardless)
    end
  end
end
