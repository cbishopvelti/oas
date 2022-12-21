defmodule Oas.Repo.Migrations.AttendanceBy do
  use Ecto.Migration

  def change do
    alter table("attendance") do
      add :inserted_by_member_id, references(:members, on_delete: :restrict), null: true
      add :undo_until, :utc_datetime, null: true
    end
  end
end
