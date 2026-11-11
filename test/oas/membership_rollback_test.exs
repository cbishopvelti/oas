defmodule Oas.MembershipRollbackTest do
  @moduledoc """
  A membership and its fee are saved together, and a booking that adds a
  membership is rolled back when the membership cannot be saved.
  """
  # Not async: Mock replaces modules globally.
  use Oas.DataCase, async: false

  import Mock

  setup do
    # temporary_trainings 0: the first booking makes the member join
    {:ok, _} =
      Oas.Settings.update_config(%{credits: true, temporary_trainings: 0}, [:credits, :temporary_trainings])

    member = Oas.MembersFixtures.member_fixture()

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

    {:ok, training} =
      %Oas.Trainings.Training{
        when: ~D[2025-10-03],
        notes: "",
        training_where_id: venue.id,
        disable_warning_emails: true
      }
      |> Repo.insert()

    %{member: member, period: period, training: training}
  end

  defp memberships(member) do
    from(m in Oas.Members.Membership, where: m.member_id == ^member.id) |> Repo.all()
  end

  defp credits(member) do
    from(c in Oas.Credits.Credit, where: c.who_member_id == ^member.id) |> Repo.all()
  end

  defp attendances(member) do
    from(a in Oas.Trainings.Attendance, where: a.member_id == ^member.id) |> Repo.all()
  end

  defp book(member, training) do
    Oas.Attendance.add_attendance(
      %{member_id: member.id, training_id: training.id},
      %{inserted_by_member_id: member.id}
    )
  end

  describe "Membership.add_membership" do
    test "returns the membership and charges its fee", ctx do
      assert {:ok, %Oas.Members.Membership{id: id}} =
               Oas.Members.Membership.add_membership(ctx.period, ctx.member, %{now: ~D[2025-10-03]})

      assert [%{id: ^id}] = memberships(ctx.member)
      assert [%{membership_id: ^id, amount: amount}] = credits(ctx.member)
      assert Decimal.eq?(amount, -12)
    end

    test "returns an error for a second membership in the same period, without charging again", ctx do
      {:ok, _} = Oas.Members.Membership.add_membership(ctx.period, ctx.member, %{now: ~D[2025-10-03]})

      assert {:error, %Ecto.Changeset{errors: [member_id: _]}} =
               Oas.Members.Membership.add_membership(ctx.period, ctx.member, %{now: ~D[2025-10-03]})

      assert length(memberships(ctx.member)) == 1
      assert length(credits(ctx.member)) == 1
    end
  end

  describe "add_attendance" do
    test "adds the membership with the booking", ctx do
      assert {:ok, %{success: true}} = book(ctx.member, ctx.training)

      assert [_] = attendances(ctx.member)
      assert [_] = memberships(ctx.member)
      # Membership fee and the training's credit
      assert length(credits(ctx.member)) == 2
    end

    test "does not keep the booking when the membership cannot be saved", ctx do
      with_mock Oas.Members.Membership, [:passthrough],
        add_membership: fn _period, _member, _opts ->
          {:error,
           %Oas.Members.Membership{}
           |> Ecto.Changeset.change()
           |> Ecto.Changeset.add_error(:member_id, "forced membership failure")}
        end do
        assert {:error, [%{message: "member_id: forced membership failure"}]} =
                 catch_throw(book(ctx.member, ctx.training))
      end

      assert attendances(ctx.member) == []
      assert memberships(ctx.member) == []
      assert credits(ctx.member) == []
    end

    # Unlike the mocked test above, this goes through the real add_membership,
    # so its own (nested) transaction fails inside the booking's transaction.
    test "does not keep the booking when the real membership insert returns an error", ctx do
      # The message makes the adapter report the membership's unique index, so
      # Repo.insert returns {:error, changeset} instead of raising.
      Repo.query!("""
      CREATE TRIGGER test_fail_membership_unique
      BEFORE INSERT ON memberships
      BEGIN
        SELECT RAISE(ABORT, 'UNIQUE constraint failed: memberships.member_id, memberships.membership_period_id');
      END
      """)

      assert {:error, [%{message: "member_id: already has a membership for this period"}]} =
               catch_throw(book(ctx.member, ctx.training))

      assert attendances(ctx.member) == []
      assert memberships(ctx.member) == []
      assert credits(ctx.member) == []
    end

    test "does not keep an earlier membership when a later overlapping period fails", ctx do
      {:ok, second} =
        %Oas.Members.MembershipPeriod{
          name: "2025 autumn",
          value: Decimal.new("3"),
          from: ~D[2025-09-01],
          to: ~D[2025-12-31]
        }
        |> Repo.insert()

      # Only the second period's membership fails; the first saves and must be undone.
      Repo.query!("""
      CREATE TRIGGER test_fail_second_membership
      BEFORE INSERT ON memberships
      WHEN NEW.membership_period_id = #{second.id}
      BEGIN
        SELECT RAISE(ABORT, 'UNIQUE constraint failed: memberships.member_id, memberships.membership_period_id');
      END
      """)

      assert {:error, [%{message: "member_id: already has a membership for this period"}]} =
               catch_throw(book(ctx.member, ctx.training))

      assert attendances(ctx.member) == []
      assert memberships(ctx.member) == []
      assert credits(ctx.member) == []
    end

    test "does not keep the booking when saving the membership raises", ctx do
      Repo.query!("""
      CREATE TRIGGER test_fail_membership_insert
      BEFORE INSERT ON memberships
      BEGIN
        SELECT RAISE(ABORT, 'forced membership failure');
      END
      """)

      assert_raise Exqlite.Error, ~r/forced membership failure/, fn ->
        book(ctx.member, ctx.training)
      end

      assert attendances(ctx.member) == []
      assert memberships(ctx.member) == []
      assert credits(ctx.member) == []
    end
  end

  describe "add_membership mutation" do
    @mutation """
    mutation ($membership_period_id: Int!, $member_id: Int!) {
      add_membership(membership_period_id: $membership_period_id, member_id: $member_id) { success }
    }
    """

    defp run(period, member) do
      Absinthe.run(@mutation, OasWeb.Schema,
        variables: %{"membership_period_id" => period.id, "member_id" => member.id},
        context: %{current_member: %{is_admin: true}}
      )
    end

    test "adds the membership", ctx do
      assert {:ok, %{data: %{"add_membership" => %{"success" => true}}}} = run(ctx.period, ctx.member)
      assert [_] = memberships(ctx.member)
    end

    test "reports an error instead of success when the membership cannot be saved", ctx do
      {:ok, _} = run(ctx.period, ctx.member)

      assert {:ok, %{errors: [%{message: "member_id: already has a membership for this period"}]}} =
               run(ctx.period, ctx.member)

      assert length(memberships(ctx.member)) == 1
      assert length(credits(ctx.member)) == 1
    end
  end
end
