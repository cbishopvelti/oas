defmodule Oas.Repo.Migrations.TransactionTagAuto do
  use Ecto.Migration

  def change do
    create table(:transaction_tag_auto) do
      add :who, :string
      add :transaction_tag_id, references(:transaction_tags, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:transaction_tag_auto, [:transaction_tag_id, :who])
  end
end
