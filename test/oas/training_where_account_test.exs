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

  test "get_account_liability only counts rows up to the given date" do
    venue = %Oas.Trainings.TrainingWhere{name: "Venue", credit_amount: Decimal.new("1")}
      |> Oas.Repo.insert!()

    for date <- [~D[2025-06-01], ~D[2026-02-01]] do
      %Oas.Trainings.Training{training_where_id: venue.id, when: date,
        venue_billing_type: :fixed, venue_billing_config: %{"fixed" => "10"}}
      |> Oas.Repo.insert!()
    end

    {total, rows} = Oas.Trainings.TrainingWhere.get_account_liability(venue.id, ~D[2025-12-31])
    assert Decimal.equal?(total, Decimal.new("10"))
    assert length(rows) == 1

    {total, _} = Oas.Trainings.TrainingWhere.get_account_liability(venue.id)
    assert Decimal.equal?(total, Decimal.new("20"))
  end

  test "fixed billing requires a fixed amount" do
    changeset = Oas.Trainings.TrainingWhere.changeset(%Oas.Trainings.TrainingWhere{}, %{
      name: "Venue", credit_amount: "1", billing_type: :fixed, billing_config: %{"other" => "1"}
    })
    refute changeset.valid?
    assert {"fixed amount must be set", _} = changeset.errors[:billing_config]

    changeset = Oas.Trainings.TrainingWhere.changeset(%Oas.Trainings.TrainingWhere{}, %{
      name: "Venue", credit_amount: "1", billing_type: :fixed, billing_config: %{"fixed" => "12.5"}
    })
    assert changeset.valid?

    training_changeset = %Oas.Trainings.Training{}
      |> Ecto.Changeset.change(%{venue_billing_type: :fixed, venue_billing_config: %{}})
      |> Oas.Trainings.Training.validate_billing()
    refute training_changeset.valid?
  end
end
