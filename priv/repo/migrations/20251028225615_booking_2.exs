defmodule Oas.Repo.Migrations.Booking2 do
  use Ecto.Migration

  def change do
    alter table(:trainings) do
      add :commitment, :boolean, null: true
    end

    alter table(:attendance) do
      add :dedub_training_member, :int, null: false, default: 1
    end

    execute(
      "
      WITH NumberedDuplicates as (
        SELECT
          id,
          ROW_NUMBER() OVER(PARTITION BY member_id, training_id ORDER BY id) as row_num
        FROM
          attendance
       	ORDER BY id ASC
      )
      UPDATE attendance
      SET dedub_training_member = NumberedDuplicates.row_num
      FROM NumberedDuplicates
      WHERE attendance.id = NumberedDuplicates.id;
    ",
      "SELECT true"
    )

    create unique_index(:attendance, [:training_id, :member_id, :dedub_training_member])
  end
end
