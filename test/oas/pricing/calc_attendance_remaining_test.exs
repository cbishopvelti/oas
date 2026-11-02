defmodule Oas.Pricing.CalcAttendanceRemainingTest do
  use Oas.DataCase

  alias Oas.Pricing.CalcAttendance

  # Bundle pricing: 5 for one training, 8 for two or more.
  @lua """
  if #user.attending >= 2 then
    return 8
  else
    return 5
  end
  """

  setup do
    member = Oas.MembersFixtures.member_fixture()

    pricing = Repo.insert!(%Oas.Pricing.Pricing{name: "Bundle"})

    pricing_instance =
      Repo.insert!(%Oas.Pricing.PricingInstance{
        name: "Bundle instance",
        pricing_id: pricing.id,
        blockly_lua: @lua,
        is_active: true
      })

    training_where = Repo.insert!(%Oas.Trainings.TrainingWhere{name: "Hall #{System.unique_integer()}"})

    training = fn date ->
      Repo.insert!(%Oas.Trainings.Training{
        when: date,
        training_where_id: training_where.id,
        credit_amount: Decimal.new("5"),
        pricing_instance_id: pricing_instance.id
      })
      |> Repo.preload(:pricing_instance)
    end

    %{
      member: member,
      first: training.(~D[2026-01-05]),
      second: training.(~D[2026-01-12])
    }
  end

  defp attend_and_pay(training, member, amount) do
    attendance =
      Repo.insert!(%Oas.Trainings.Attendance{training_id: training.id, member_id: member.id})

    Repo.insert!(%Oas.Credits.Credit{
      what: "Attendance",
      amount: Decimal.new(amount),
      when: training.when,
      who_member_id: member.id,
      attendance_id: attendance.id
    })
  end

  defp prices(result), do: Enum.map(result, fn {training, amount} -> {training.id, amount} end)

  describe "calculate_price/3 with distribution_mode: :remaining" do
    test "with nothing booked, the training costs the full price", %{member: member, first: first} do
      result = CalcAttendance.calculate_price(first, member, distribution_mode: :remaining)

      assert [{id, amount}] = prices(result)
      assert id == first.id
      assert Decimal.eq?(amount, "5")
    end

    test "puts the bundle price minus what is already paid on the new training",
         %{member: member, first: first, second: second} do
      attend_and_pay(first, member, "-5")

      result = CalcAttendance.calculate_price(second, member, distribution_mode: :remaining)

      assert [{second_id, second_amount}, {first_id, first_amount}] = prices(result)
      assert second_id == second.id
      assert Decimal.eq?(second_amount, "3")
      # The already booked training keeps what was paid for it
      assert first_id == first.id
      assert Decimal.eq?(first_amount, "5")
    end

    test "the shown price is what booking adds under :redistribute",
         %{member: member, first: first, second: second} do
      attend_and_pay(first, member, "-5")

      [{_, remaining_price} | _] =
        CalcAttendance.calculate_price(second, member, distribution_mode: :remaining)

      redistributed = CalcAttendance.calculate_price(second, member)
      total_after = redistributed |> Enum.map(&elem(&1, 1)) |> Enum.reduce(&Decimal.add/2)

      assert Decimal.eq?(total_after, "8")
      assert Decimal.eq?(Decimal.sub(total_after, "5"), remaining_price)
    end
  end
end
