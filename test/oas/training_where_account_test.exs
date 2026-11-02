defmodule Oas.TrainingWhereAccountTest do
  use Oas.DataCase

  test "get_account_liability keeps every row in date order" do
    venue = %Oas.Trainings.TrainingWhere{name: "Venue", credit_amount: Decimal.new("1")}
      |> Oas.Repo.insert!()

    training = fn date ->
      %Oas.Trainings.Training{training_where_id: venue.id, when: date,
        venue_billing_type: :fixed, venue_billing_config: %{"fixed" => "10"}}
      |> Oas.Repo.insert!()
    end

    transaction = fn date, amount ->
      %Oas.Transactions.Transaction{what: "Venue payment", when: date, who: "Venue",
        type: "OUTGOING", my_reference: "venue", amount: Decimal.new(amount), training_where_id: venue.id}
      |> Oas.Repo.insert!()
    end

    # Day-of-month order differs from real date order, so a term-order sort
    # of Date structs would mix these up.
    training.(~D[2025-01-20])
    transaction.(~D[2025-02-05], "-10")
    training.(~D[2025-03-01])
    transaction.(~D[2025-03-15], "-5")

    {total, rows} = Oas.Trainings.TrainingWhere.get_account_liability(venue.id)

    assert Decimal.equal?(total, Decimal.new("5"))

    # Rows are newest first.
    assert Enum.map(rows, fn {_acc, _amount, %{when: w}} -> w end) ==
      [~D[2025-03-15], ~D[2025-03-01], ~D[2025-02-05], ~D[2025-01-20]]

    assert Enum.map(rows, fn {acc, _, _} -> Decimal.to_integer(acc) end) ==
      [5, 10, 0, 10]
  end
end
