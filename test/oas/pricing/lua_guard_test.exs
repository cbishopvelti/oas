defmodule Oas.Pricing.LuaGuardTest do
  @moduledoc """
  A broken pricing rule (one that loops forever, uses too much memory, raises,
  or returns something that isn't a price) must give a clear error instead of
  hanging or crashing a booking, and must not leave a booking half done.
  """
  use Oas.DataCase

  import ExUnit.CaptureLog

  alias Oas.Pricing.CalcAttendance

  @inputs %{membership_status: :full_member, attending: [1.0], trainings: [5.0], now: "2025-10-03"}

  describe "run_lua/3" do
    test "returns the price" do
      assert {:ok, amount} = CalcAttendance.run_lua("return 10", @inputs)
      assert Decimal.eq?(amount, 10)
    end

    test "passes the inputs to the rule" do
      lua = ~s|if user.membership_status == "full_member" and now == "2025-10-03" then return trainings[1] * 2 else return 0 end|
      assert {:ok, amount} = CalcAttendance.run_lua(lua, @inputs)
      assert Decimal.eq?(amount, 10)
    end

    test "stops a rule that never finishes" do
      assert {:error, reason} = CalcAttendance.run_lua("while true do end", @inputs, timeout: 200)
      assert reason =~ "took longer than 200ms"
    end

    test "stops a rule that uses too much memory" do
      lua = "local t = {} for i = 1, 100000000 do t[i] = i end return 1"

      assert {:error, reason} =
               CalcAttendance.run_lua(lua, @inputs, max_heap_words: 1_000_000, timeout: 10_000)

      assert reason =~ "too much memory"
    end

    test "reports a rule that doesn't compile" do
      assert {:error, reason} = CalcAttendance.run_lua("return (", @inputs)
      assert reason =~ "doesn't compile"
    end

    test "reports a rule that raises" do
      assert {:error, reason} = CalcAttendance.run_lua(~s|error("boom")|, @inputs)
      assert reason =~ "failed"
    end

    test "reports a rule that returns nothing" do
      assert {:error, reason} = CalcAttendance.run_lua("local x = 1", @inputs)
      assert reason =~ "didn't return a price"
    end

    test "reports a rule that returns nil" do
      assert {:error, reason} = CalcAttendance.run_lua("return nil", @inputs)
      assert reason =~ "must return a number"
    end

    test "reports a rule that returns a non-numeric string" do
      assert {:error, _reason} = CalcAttendance.run_lua(~s|return "free"|, @inputs)
    end

    test "reports a negative price" do
      assert {:error, reason} = CalcAttendance.run_lua("return -5", @inputs)
      assert reason =~ "negative price"
    end

    test "reports a missing rule" do
      assert {:error, _reason} = CalcAttendance.run_lua(nil, @inputs)
      assert {:error, _reason} = CalcAttendance.run_lua("", @inputs)
    end
  end

  describe "booking with a broken rule" do
    setup do
      from(c in Oas.Config.Config) |> Repo.update_all(set: [credits: true])

      member = Oas.MembersFixtures.member_fixture()

      pricing = Repo.insert!(%Oas.Pricing.Pricing{name: "broken #{System.unique_integer()}"})

      pricing_instance =
        Repo.insert!(%Oas.Pricing.PricingInstance{
          name: "broken",
          is_active: true,
          blockly_lua: ~s|error("boom")|,
          pricing_id: pricing.id
        })

      {:ok, venue} =
        %Oas.Trainings.TrainingWhere{}
        |> Oas.Trainings.TrainingWhere.changeset(%{name: "venue #{System.unique_integer()}", credit_amount: 5})
        |> Repo.insert()

      training =
        Repo.insert!(%Oas.Trainings.Training{
          when: ~D[2025-10-03],
          notes: "",
          training_where_id: venue.id,
          exempt_membership_count: true,
          disable_warning_emails: true,
          pricing_instance_id: pricing_instance.id
        })

      %{member: member, training: training}
    end

    test "calculate_price returns an error and logs the reason", %{member: member, training: training} do
      training = Repo.preload(training, :pricing_instance)

      log =
        capture_log(fn ->
          assert {:error, message} = CalcAttendance.calculate_price(training, member)
          assert message =~ "couldn't be calculated"
        end)

      assert log =~ "Pricing rule failed"
      assert log =~ "boom"
    end

    test "add_attendance fails cleanly and keeps no attendance", %{member: member, training: training} do
      capture_log(fn ->
        assert {:error, message} =
                 catch_throw(
                   Oas.Attendance.add_attendance(
                     %{member_id: member.id, training_id: training.id},
                     %{inserted_by_member_id: member.id}
                   )
                 )

        assert message =~ "couldn't be calculated"
      end)

      assert Repo.one(
               from(a in Oas.Trainings.Attendance,
                 where: a.member_id == ^member.id and a.training_id == ^training.id
               )
             ) == nil

      assert Repo.one(
               from(c in Oas.Credits.Credit, where: c.who_member_id == ^member.id, select: count(c.id))
             ) == 0
    end
  end
end
