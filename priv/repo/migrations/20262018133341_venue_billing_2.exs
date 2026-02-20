defmodule Oas.Repo.Migrations.VenueBilling2 do
  use Ecto.Migration

  def change do

    alter table(:transactions) do
      add :training_where_id, references(:training_where, on_delete: :restrict), null: true
    end
  end
end
