defmodule OasWeb.Schema.UserUndoAttendanceTest do
  @moduledoc """
  A member's undo must only report success when the booking was really
  deleted. A failed delete rolls back, so the booking still stands.
  """
  # Not async: Mock replaces modules globally.
  use Oas.DataCase, async: false

  import Mock

  @mutation """
  mutation ($attendance_id: Int!) {
    user_undo_attendance(attendance_id: $attendance_id) { success }
  }
  """

  setup do
    {:ok, _} = Oas.TestConfig.update_config(%{credits: true, enable_booking: true}, [:credits, :enable_booking])

    member = Oas.MembersFixtures.member_fixture()

    {:ok, pricing} =
      %Oas.Pricing.Pricing{name: "test pricing #{System.unique_integer()}"} |> Repo.insert()

    {:ok, pricing_instance} =
      %Oas.Pricing.PricingInstance{
        name: "test instance",
        is_active: true,
        blockly_lua: "return 10",
        pricing_id: pricing.id
      }
      |> Repo.insert()

    {:ok, venue} =
      %Oas.Trainings.TrainingWhere{}
      |> Oas.Trainings.TrainingWhere.changeset(%{name: "test venue #{System.unique_integer()}", credit_amount: 5})
      |> Repo.insert()

    # Two future trainings in one bundle, so undoing one re-spreads the price
    # over the other. Future, so the undo is before the booking cutoff.
    [training_a, training_b] =
      for days <- [7, 8] do
        %Oas.Trainings.Training{
          when: Date.add(Date.utc_today(), days),
          notes: "",
          training_where_id: venue.id,
          pricing_instance_id: pricing_instance.id,
          exempt_membership_count: true,
          disable_warning_emails: true
        }
        |> Repo.insert!()
      end

    for training <- [training_a, training_b] do
      {:ok, _} =
        Oas.Attendance.add_attendance(
          %{member_id: member.id, training_id: training.id},
          %{inserted_by_member_id: member.id}
        )
    end

    %{member: member, training_a: training_a, training_b: training_b}
  end

  defp attendance(member, training) do
    from(a in Oas.Trainings.Attendance,
      where: a.member_id == ^member.id and a.training_id == ^training.id
    )
    |> Repo.one()
  end

  defp undo(member, attendance) do
    Absinthe.run(@mutation, OasWeb.Schema,
      variables: %{"attendance_id" => attendance.id},
      context: %{current_member: %{member | is_active: true}}
    )
  end

  test "reports success and deletes the booking", ctx do
    attendance = attendance(ctx.member, ctx.training_a)

    assert {:ok, %{data: %{"user_undo_attendance" => %{"success" => true}}}} = undo(ctx.member, attendance)
    assert attendance(ctx.member, ctx.training_a) == nil
  end

  test "reports the error when the delete rolls back on a failed credit write", ctx do
    attendance = attendance(ctx.member, ctx.training_a)

    failing_credit_update =
      {Oas.Repo, [:passthrough],
       update: fn
         %Ecto.Changeset{data: %Oas.Credits.Credit{}} = changeset ->
           {:error, Ecto.Changeset.add_error(changeset, :amount, "forced credit write failure")}

         changeset ->
           :meck.passthrough([changeset])
       end}

    with_mocks [failing_credit_update] do
      assert {:ok, %{data: %{"user_undo_attendance" => nil}, errors: [%{message: message}]}} =
               undo(ctx.member, attendance)

      assert message =~ "forced credit write failure"
    end

    # Rolled back: the booking is still there
    assert attendance(ctx.member, ctx.training_a) != nil
  end

  test "reports a generic error when the delete fails for another reason", ctx do
    attendance = attendance(ctx.member, ctx.training_a)

    with_mock Oas.Attendance, [:passthrough], delete_attendance: fn _ -> {:error, {:lua, :boom}} end do
      assert {:ok, %{data: %{"user_undo_attendance" => nil}, errors: [%{message: "Unable to undo" <> _}]}} =
               undo(ctx.member, attendance)
    end

    assert attendance(ctx.member, ctx.training_a) != nil
  end
end
