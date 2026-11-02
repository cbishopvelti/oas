defmodule Oas.Pricing.CalcAttendanceDateTest do
  use Oas.DataCase

  alias Oas.Pricing.CalcAttendance

  test "Lua `now` is the training date, not today" do
    member = Oas.MembersFixtures.member_fixture()

    pricing = Oas.Repo.insert!(%Oas.Pricing.Pricing{name: "date rule"})

    pricing_instance =
      Oas.Repo.insert!(%Oas.Pricing.PricingInstance{
        name: "date rule",
        pricing_id: pricing.id,
        blockly_lua: ~s|if now == "2020-01-01" then return 5 else return 7 end|
      })

    where = Oas.Repo.insert!(%Oas.Trainings.TrainingWhere{name: "hall"})

    training =
      Oas.Repo.insert!(%Oas.Trainings.Training{
        training_where_id: where.id,
        when: ~D[2020-01-01],
        pricing_instance_id: pricing_instance.id
      })
      |> Oas.Repo.preload(:pricing_instance)

    [{_training, amount}] = CalcAttendance.calculate_price(training, member)
    assert Decimal.eq?(amount, Decimal.new("5"))
  end
end
