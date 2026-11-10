defmodule Oas.Pricing.CreditWriteRollbackTest do
  @moduledoc """
  Adding or deleting an attendance and writing its credits must happen together:
  if any credit write fails, the attendance change must be rolled back too.

  A credit write can fail in two ways, and both are covered:

    * it returns `{:error, changeset}`, simulated by mocking the write;
    * it raises, simulated with SQLite triggers that abort the statement. The
      triggers are created inside the test's sandbox transaction, so they are
      dropped again when the test ends.
  """
  # Not async: Mock replaces modules globally.
  use Oas.DataCase, async: false

  import Mock

  # Total price of the pricing instance, spread over the trainings attended.
  @lua "return 10"

  setup do
    {:ok, _} = Oas.Settings.update_config(%{credits: true}, [:credits])

    member = Oas.MembersFixtures.member_fixture()

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
      |> Oas.Trainings.TrainingWhere.changeset(%{name: "test venue #{System.unique_integer()}", credit_amount: 5})
      |> Repo.insert()

    [training_a, training_b] =
      for day <- [3, 4] do
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

    %{member: member, training_a: training_a, training_b: training_b}
  end

  defp add(member, training) do
    Oas.Attendance.add_attendance(
      %{member_id: member.id, training_id: training.id},
      %{inserted_by_member_id: member.id}
    )
  end

  defp attendance(member, training) do
    from(a in Oas.Trainings.Attendance,
      where: a.member_id == ^member.id and a.training_id == ^training.id,
      preload: :credit
    )
    |> Repo.one()
  end

  defp credit_amount(member, training) do
    attendance(member, training).credit.amount
  end

  defp credit_count(member) do
    from(c in Oas.Credits.Credit, where: c.who_member_id == ^member.id, select: count(c.id))
    |> Repo.one()
  end

  defp fail_credit_writes(event) when event in ["INSERT", "UPDATE"] do
    Repo.query!("""
    CREATE TRIGGER test_fail_credit_#{String.downcase(event)}
    BEFORE #{event} ON credits
    BEGIN
      SELECT RAISE(ABORT, 'forced credit write failure');
    END
    """)
  end

  defp credit_error(changeset) do
    {:error, Ecto.Changeset.add_error(changeset, :amount, "forced credit write failure")}
  end

  # Makes Repo.update/1 return an error for credit changesets only, so the
  # attendance and other writes still go through.
  defp repo_update_failing_credits do
    [
      update: fn
        %Ecto.Changeset{data: %Oas.Credits.Credit{}} = changeset -> credit_error(changeset)
        changeset -> :meck.passthrough([changeset])
      end
    ]
  end

  describe "add_attendance" do
    test "charges the training and re-spreads the price over attended trainings", ctx do
      assert {:ok, %{success: true}} = add(ctx.member, ctx.training_a)
      assert Decimal.eq?(credit_amount(ctx.member, ctx.training_a), -10)

      assert {:ok, %{success: true}} = add(ctx.member, ctx.training_b)
      assert Decimal.eq?(credit_amount(ctx.member, ctx.training_a), -5)
      assert Decimal.eq?(credit_amount(ctx.member, ctx.training_b), -5)
    end

    test "does not keep the attendance when writing its credit returns an error", ctx do
      with_mock Oas.Credits.Credit, [:passthrough],
        deduct_credit: fn attendance, _member, _amount, _opts ->
          attendance |> Ecto.Changeset.change() |> credit_error()
        end do
        assert {:error, _} = catch_throw(add(ctx.member, ctx.training_a))
      end

      assert attendance(ctx.member, ctx.training_a) == nil
      assert credit_count(ctx.member) == 0
    end

    test "does not keep the attendance when re-spreading another training's credit returns an error",
         ctx do
      {:ok, _} = add(ctx.member, ctx.training_a)

      with_mock Oas.Repo, [:passthrough], repo_update_failing_credits() do
        assert {:error, _} = catch_throw(add(ctx.member, ctx.training_b))
      end

      assert attendance(ctx.member, ctx.training_b) == nil
      assert credit_count(ctx.member) == 1
      assert Decimal.eq?(credit_amount(ctx.member, ctx.training_a), -10)
    end

    test "does not keep the attendance when writing its credit raises", ctx do
      fail_credit_writes("INSERT")

      assert_raise Exqlite.Error, ~r/forced credit write failure/, fn ->
        add(ctx.member, ctx.training_a)
      end

      assert attendance(ctx.member, ctx.training_a) == nil
      assert credit_count(ctx.member) == 0
    end

    test "does not keep the attendance when re-spreading another training's credit raises", ctx do
      {:ok, _} = add(ctx.member, ctx.training_a)
      fail_credit_writes("UPDATE")

      assert_raise Exqlite.Error, ~r/forced credit write failure/, fn ->
        add(ctx.member, ctx.training_b)
      end

      assert attendance(ctx.member, ctx.training_b) == nil
      assert credit_count(ctx.member) == 1
      assert Decimal.eq?(credit_amount(ctx.member, ctx.training_a), -10)
    end
  end

  describe "delete_attendance" do
    setup ctx do
      {:ok, _} = add(ctx.member, ctx.training_a)
      {:ok, _} = add(ctx.member, ctx.training_b)
      :ok
    end

    test "re-spreads the price over the remaining attendance", ctx do
      %{id: id} = attendance(ctx.member, ctx.training_b)

      assert {:ok, %{success: true}} = Oas.Attendance.delete_attendance(%{attendance_id: id})

      assert attendance(ctx.member, ctx.training_b) == nil
      assert Decimal.eq?(credit_amount(ctx.member, ctx.training_a), -10)
    end

    test "keeps the attendance when re-spreading the remaining credit returns an error", ctx do
      %{id: id} = attendance(ctx.member, ctx.training_b)

      with_mock Oas.Repo, [:passthrough], repo_update_failing_credits() do
        assert {:error, _} = Oas.Attendance.delete_attendance(%{attendance_id: id})
      end

      assert %{id: ^id} = attendance(ctx.member, ctx.training_b)
      assert Decimal.eq?(credit_amount(ctx.member, ctx.training_a), -5)
      assert Decimal.eq?(credit_amount(ctx.member, ctx.training_b), -5)
    end

    test "keeps the attendance when re-spreading the remaining credit raises", ctx do
      %{id: id} = attendance(ctx.member, ctx.training_b)
      fail_credit_writes("UPDATE")

      assert_raise Exqlite.Error, ~r/forced credit write failure/, fn ->
        Oas.Attendance.delete_attendance(%{attendance_id: id})
      end

      assert %{id: ^id} = attendance(ctx.member, ctx.training_b)
      assert Decimal.eq?(credit_amount(ctx.member, ctx.training_a), -5)
      assert Decimal.eq?(credit_amount(ctx.member, ctx.training_b), -5)
    end
  end
end
