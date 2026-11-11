defmodule Oas.MergeMembersTest do
  @moduledoc """
  `Oas.Members.merge_members!/3` moves every attendance from one member to
  another. It must be all or nothing: if any attendance cannot be moved, both
  members must be left exactly as they were.
  """
  use Oas.DataCase, async: false

  # Total price of the pricing instance, spread over the trainings attended.
  @lua "return 10"

  setup do
    {:ok, _} = Oas.TestConfig.update_config(%{credits: true}, [:credits])

    from_member = Oas.MembersFixtures.member_fixture()
    to_member = Oas.MembersFixtures.member_fixture()

    {:ok, pricing} =
      %Oas.Pricing.Pricing{name: "test pricing #{System.unique_integer()}"} |> Repo.insert()

    {:ok, pricing_instance} =
      %Oas.Pricing.PricingInstance{
        name: "test instance",
        is_active: true,
        blockly_lua: @lua,
        pricing_id: pricing.id
      }
      |> Repo.insert()

    {:ok, venue} =
      %Oas.Trainings.TrainingWhere{}
      |> Oas.Trainings.TrainingWhere.changeset(%{
        name: "test venue #{System.unique_integer()}",
        credit_amount: 5
      })
      |> Repo.insert()

    [training_a, training_b, training_c] =
      for day <- [3, 4, 5] do
        {:ok, training} =
          %Oas.Trainings.Training{
            when: Date.new!(2025, 10, day),
            notes: "",
            training_where_id: venue.id,
            exempt_membership_count: true,
            disable_warning_emails: true,
            pricing_instance_id: pricing_instance.id
          }
          |> Repo.insert()

        training
      end

    %{
      from: from_member,
      to: to_member,
      training_a: training_a,
      training_b: training_b,
      training_c: training_c
    }
  end

  defp add(member, training) do
    assert {:ok, %{success: true}} =
             Oas.Attendance.add_attendance(
               %{member_id: member.id, training_id: training.id},
               %{inserted_by_member_id: member.id}
             )
  end

  defp merge(ctx) do
    Oas.Members.merge_members!(ctx.from.id, ctx.to.id, inserted_by_member_id: ctx.to.id)
  end

  # Everything a merge can touch for one member: their attendances with the
  # credit on each, and every credit row they own.
  defp snapshot(member) do
    attendances =
      from(a in Oas.Trainings.Attendance,
        left_join: c in assoc(a, :credit),
        where: a.member_id == ^member.id,
        order_by: [asc: a.training_id],
        select: {a.id, a.training_id, c.amount}
      )
      |> Repo.all()
      |> Enum.map(fn {id, training_id, amount} -> {id, training_id, decimal(amount)} end)

    credits =
      from(c in Oas.Credits.Credit,
        where: c.who_member_id == ^member.id,
        order_by: [asc: c.id],
        select: {c.id, c.amount, c.attendance_id}
      )
      |> Repo.all()
      |> Enum.map(fn {id, amount, attendance_id} -> {id, decimal(amount), attendance_id} end)

    %{attendances: attendances, credits: credits}
  end

  defp decimal(nil), do: nil
  defp decimal(amount), do: Decimal.to_string(Decimal.normalize(amount))

  defp training_ids(member) do
    snapshot(member).attendances |> Enum.map(fn {_, training_id, _} -> training_id end)
  end

  test "moves every attendance and its charge to the other member", ctx do
    add(ctx.from, ctx.training_a)
    add(ctx.from, ctx.training_b)

    moved = merge(ctx)

    assert length(moved) == 2
    assert training_ids(ctx.from) == []
    assert snapshot(ctx.from).credits == []

    assert training_ids(ctx.to) == [ctx.training_a.id, ctx.training_b.id]
    # The bundle price is re-spread over both trainings for the new member.
    assert Enum.map(snapshot(ctx.to).attendances, &elem(&1, 2)) == ["-5", "-5"]
  end

  test "does nothing when the member has no attendance", ctx do
    add(ctx.to, ctx.training_a)
    before = {snapshot(ctx.from), snapshot(ctx.to)}

    assert merge(ctx) == []
    assert {snapshot(ctx.from), snapshot(ctx.to)} == before
  end

  test "a re-add that fails partway rolls back the whole merge", ctx do
    # The target already attends training_b, so moving that attendance fails
    # on the unique index after training_a has already been moved.
    add(ctx.from, ctx.training_a)
    add(ctx.from, ctx.training_b)
    add(ctx.from, ctx.training_c)
    add(ctx.to, ctx.training_b)

    before_from = snapshot(ctx.from)
    before_to = snapshot(ctx.to)

    error = assert_raise RuntimeError, fn -> merge(ctx) end
    assert error.message =~ "rolled back, nothing was changed"
    assert error.message =~ "#{ctx.training_b.id}"

    assert snapshot(ctx.from) == before_from
    assert snapshot(ctx.to) == before_to
    assert training_ids(ctx.from) == [ctx.training_a.id, ctx.training_b.id, ctx.training_c.id]
    assert training_ids(ctx.to) == [ctx.training_b.id]
  end

  test "a database error partway rolls back the whole merge", ctx do
    add(ctx.from, ctx.training_a)
    add(ctx.from, ctx.training_b)

    before_from = snapshot(ctx.from)
    before_to = snapshot(ctx.to)

    # Inserting the target's attendance at training_b raises, after
    # training_a has been moved and training_b deleted from the source.
    # Created inside the test's sandbox transaction, so it is dropped after.
    Repo.query!("""
    CREATE TRIGGER test_fail_merge_insert
    BEFORE INSERT ON attendance
    WHEN NEW.member_id = #{ctx.to.id} AND NEW.training_id = #{ctx.training_b.id}
    BEGIN
      SELECT RAISE(ABORT, 'forced attendance insert failure');
    END
    """)

    assert_raise Exqlite.Error, ~r/forced attendance insert failure/, fn -> merge(ctx) end

    assert snapshot(ctx.from) == before_from
    assert snapshot(ctx.to) == before_to
  end

  test "a delete that fails partway rolls back the whole merge", ctx do
    add(ctx.from, ctx.training_a)
    add(ctx.from, ctx.training_b)

    before_from = snapshot(ctx.from)
    before_to = snapshot(ctx.to)

    Repo.query!("""
    CREATE TRIGGER test_fail_merge_delete
    BEFORE DELETE ON attendance
    WHEN OLD.member_id = #{ctx.from.id} AND OLD.training_id = #{ctx.training_b.id}
    BEGIN
      SELECT RAISE(ABORT, 'forced attendance delete failure');
    END
    """)

    assert_raise Exqlite.Error, ~r/forced attendance delete failure/, fn -> merge(ctx) end

    assert snapshot(ctx.from) == before_from
    assert snapshot(ctx.to) == before_to
  end
end
