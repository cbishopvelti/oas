defmodule Oas.Repo.Migrations.MembershipFromBooking do
  use Ecto.Migration

  # true when a booking earned the membership (Oas.Attendance.add_attendance),
  # false when an admin added it by hand or a bank payment paid for it. Undoing
  # a booking only removes memberships with from_booking = true.
  #
  # Existing rows: a membership with no paying transaction is marked as
  # booking-earned when the member has a booking in that period saved within
  # 5 seconds of it (a booking saves its membership in the same database
  # transaction). Every other existing row counts as added by hand, so undo
  # never removes it.
  def up do
    alter table(:memberships) do
      add :from_booking, :boolean, null: false, default: false
    end

    flush()

    execute("""
    UPDATE memberships SET from_booking = 1
    WHERE transaction_id IS NULL AND EXISTS (
      SELECT 1 FROM attendance a
      INNER JOIN trainings t ON t.id = a.training_id
      INNER JOIN membership_periods mp ON mp.id = memberships.membership_period_id
      WHERE a.member_id = memberships.member_id
        AND t."when" >= mp."from" AND t."when" <= mp."to"
        AND abs(julianday(a.inserted_at) - julianday(memberships.inserted_at)) * 86400 <= 5
    )
    """)
  end

  def down do
    alter table(:memberships) do
      remove :from_booking
    end
  end
end
