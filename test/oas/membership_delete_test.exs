defmodule Oas.MembershipDeleteTest do
  @moduledoc """
  Undoing a booking removes the membership that booking earned (refunding its
  fee), unless the member's remaining bookings still earn it.
  """
  use Oas.DataCase, async: false

  setup do
    configure(0)

    {:ok, period} =
      %Oas.Members.MembershipPeriod{
        name: "2025",
        value: Decimal.new("12"),
        from: ~D[2025-01-01],
        to: ~D[2025-12-31]
      }
      |> Repo.insert()

    {:ok, venue} =
      %Oas.Trainings.TrainingWhere{}
      |> Oas.Trainings.TrainingWhere.changeset(%{name: "test venue #{System.unique_integer()}", credit_amount: 5})
      |> Repo.insert()

    %{member: Oas.MembersFixtures.member_fixture(), period: period, venue: venue}
  end

  # temporary_trainings: bookings a member may make before they must join
  defp configure(temporary_trainings, credits \\ true) do
    {:ok, _} =
      Oas.TestConfig.update_config(
        %{credits: credits, temporary_trainings: temporary_trainings},
        [:credits, :temporary_trainings]
      )
  end

  defp training(ctx, when1, attrs \\ %{}) do
    {:ok, training} =
      %Oas.Trainings.Training{
        when: when1,
        notes: "",
        training_where_id: ctx.venue.id,
        disable_warning_emails: true
      }
      |> Map.merge(attrs)
      |> Repo.insert()

    training
  end

  defp book(member, training) do
    {:ok, %{id: id}} =
      Oas.Attendance.add_attendance(
        %{member_id: member.id, training_id: training.id},
        %{inserted_by_member_id: member.id}
      )

    id
  end

  defp undo(attendance_id), do: Oas.Attendance.delete_attendance(%{attendance_id: attendance_id})

  defp memberships(member) do
    from(m in Oas.Members.Membership, where: m.member_id == ^member.id) |> Repo.all()
  end

  defp attendances(member) do
    from(a in Oas.Trainings.Attendance, where: a.member_id == ^member.id) |> Repo.all()
  end

  defp balance(member) do
    from(c in Oas.Credits.Credit, where: c.who_member_id == ^member.id, select: c.amount)
    |> Repo.all()
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
  end

  test "undoing the booking that made someone a member removes the membership and refunds the fee", ctx do
    id = book(ctx.member, training(ctx, ~D[2025-10-03]))
    assert [_] = memberships(ctx.member)
    assert Decimal.eq?(balance(ctx.member), -17)

    assert {:ok, %{success: true}} = undo(id)

    assert attendances(ctx.member) == []
    assert memberships(ctx.member) == []
    assert Decimal.eq?(balance(ctx.member), 0)
  end

  test "the membership stays while another booking in the period still earns it", ctx do
    id = book(ctx.member, training(ctx, ~D[2025-10-03]))
    book(ctx.member, training(ctx, ~D[2025-10-10]))

    assert {:ok, _} = undo(id)

    assert [_] = memberships(ctx.member)
    # The fee and the remaining training
    assert Decimal.eq?(balance(ctx.member), -17)
  end

  test "dropping back under the temporary trainings limit removes the membership", ctx do
    configure(2)

    book(ctx.member, training(ctx, ~D[2025-10-03]))
    book(ctx.member, training(ctx, ~D[2025-10-10]))
    assert memberships(ctx.member) == []

    # The third booking is over the limit, so it adds the membership
    id = book(ctx.member, training(ctx, ~D[2025-10-17]))
    assert [_] = memberships(ctx.member)

    assert {:ok, _} = undo(id)

    assert memberships(ctx.member) == []
    assert Decimal.eq?(balance(ctx.member), -10)
  end

  test "a member of an earlier period keeps this period's membership while they have a booking in it", ctx do
    configure(5)

    {:ok, last_year} =
      %Oas.Members.MembershipPeriod{
        name: "2024",
        value: Decimal.new("10"),
        from: ~D[2024-01-01],
        to: ~D[2024-12-31]
      }
      |> Repo.insert()

    {:ok, old} = Oas.Members.Membership.add_membership(last_year, ctx.member, %{now: ~D[2024-05-01]})

    first = book(ctx.member, training(ctx, ~D[2025-10-03]))
    second = book(ctx.member, training(ctx, ~D[2025-10-10]))
    assert length(memberships(ctx.member)) == 2

    assert {:ok, _} = undo(first)
    assert length(memberships(ctx.member)) == 2

    # No booking left in 2025: that membership goes, last year's stays
    assert {:ok, _} = undo(second)
    assert [%{id: id}] = memberships(ctx.member)
    assert id == old.id
    assert Decimal.eq?(balance(ctx.member), -10)
  end

  test "a booking marks the membership it earns as earned by a booking", ctx do
    book(ctx.member, training(ctx, ~D[2025-10-03]))
    assert [%{from_booking: true}] = memberships(ctx.member)
  end

  test "a membership an admin added is kept when the member undoes a booking in that period", ctx do
    # As the admin add_membership mutation does
    {:ok, _} = Oas.Members.Membership.add_membership(ctx.period, ctx.member, %{now: ~D[2025-09-01]})

    id = book(ctx.member, training(ctx, ~D[2025-10-03]))
    assert {:ok, _} = undo(id)

    assert [%{from_booking: false}] = memberships(ctx.member)
    assert Decimal.eq?(balance(ctx.member), -12)
  end

  test "a membership an admin added for a member under the temporary limit is kept on undo", ctx do
    configure(2)
    {:ok, _} = Oas.Members.Membership.add_membership(ctx.period, ctx.member, %{now: ~D[2025-09-01]})

    id = book(ctx.member, training(ctx, ~D[2025-10-03]))
    assert {:ok, _} = undo(id)

    assert [_] = memberships(ctx.member)
  end

  test "a membership paid for by a bank transaction is kept", ctx do
    {:ok, transaction} =
      %Oas.Transactions.Transaction{
        what: "Membership",
        who: ctx.member.name,
        who_member_id: ctx.member.id,
        type: "INCOMING",
        my_reference: "",
        their_reference: "",
        amount: Decimal.new("12"),
        when: ~D[2025-09-01]
      }
      |> Repo.insert()

    {:ok, _} =
      %Oas.Members.Membership{
        member_id: ctx.member.id,
        membership_period_id: ctx.period.id,
        transaction_id: transaction.id
      }
      |> Repo.insert()

    id = book(ctx.member, training(ctx, ~D[2025-10-03]))
    assert {:ok, _} = undo(id)

    assert [%{transaction_id: transaction_id}] = memberships(ctx.member)
    assert transaction_id == transaction.id
  end

  test "undoing a training that doesn't count towards membership keeps the membership", ctx do
    {:ok, _} = Oas.Members.Membership.add_membership(ctx.period, ctx.member, %{now: ~D[2025-09-01]})

    id = book(ctx.member, training(ctx, ~D[2025-10-03], %{exempt_membership_count: true}))
    assert {:ok, _} = undo(id)

    assert [_] = memberships(ctx.member)
    assert Decimal.eq?(balance(ctx.member), -12)
  end

  test "a booking that doesn't count towards membership doesn't hold the membership", ctx do
    id = book(ctx.member, training(ctx, ~D[2025-10-03]))
    book(ctx.member, training(ctx, ~D[2025-10-10], %{exempt_membership_count: true}))
    assert [_] = memberships(ctx.member)

    assert {:ok, _} = undo(id)

    assert memberships(ctx.member) == []
  end

  test "memberships are left alone when credits are off", ctx do
    {:ok, _} = Oas.Members.Membership.add_membership(ctx.period, ctx.member, %{now: ~D[2025-09-01]})
    configure(0, false)

    id = book(ctx.member, training(ctx, ~D[2025-10-03]))
    assert {:ok, _} = undo(id)

    assert [_] = memberships(ctx.member)
  end

  test "the undo is rolled back when the membership can't be deleted", ctx do
    id = book(ctx.member, training(ctx, ~D[2025-10-03]))

    Repo.query!("""
    CREATE TRIGGER test_fail_membership_delete
    BEFORE DELETE ON memberships
    BEGIN
      SELECT RAISE(ABORT, 'forced membership delete failure');
    END
    """)

    assert_raise Exqlite.Error, ~r/forced membership delete failure/, fn -> undo(id) end

    assert [%{id: ^id}] = attendances(ctx.member)
    assert [_] = memberships(ctx.member)
    assert Decimal.eq?(balance(ctx.member), -17)
  end
end
