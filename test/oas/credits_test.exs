defmodule Oas.CreditsTest do
  use Oas.DataCase

  describe "credits" do
    # mix test --only only
    @tag only: true
    test "Adds up credits" do
      # Ecto.Adapters.SQL.Sandbox.checkout(Oas.Repo, sandbox: false)
      {transaction, member} = Oas.TransactionFixtures.transaction_fixture()

      # expired credits
      income1 = %Oas.Credits.Credits{}
      |> Ecto.Changeset.cast(%{
        what: "Stuff",
        amount: Decimal.new("3.0"),
        when: Date.from_iso8601!("2025-02-01"),
        # transaction: transaction |> Map.from_struct(),
        # member: member |> Map.from_struct(),
        expires_on: Date.from_iso8601!("2025-02-01")
      }, [:what, :amount, :when, :expires_on
      ])
      |> Ecto.Changeset.put_assoc(:transaction, transaction)
      |> Ecto.Changeset.put_assoc(:member, member)
      |> Oas.Repo.insert!()

      _income2 = %Oas.Credits.Credits{}
      |> Ecto.Changeset.cast(%{
        what: "Stuff",
        amount: Decimal.new("3.0"),
        when: Date.from_iso8601!("2025-02-01"),
        # transaction: transaction |> Map.from_struct(),
        # member: member |> Map.from_struct(),
        expires_on: Date.from_iso8601!("2025-02-03")
      }, [:what, :amount, :when, :expires_on
      ])
      |> Ecto.Changeset.put_assoc(:transaction, transaction)
      |> Ecto.Changeset.put_assoc(:member, member)
      |> Oas.Repo.insert!()

      _used = %Oas.Credits.Credits{}
      |> Ecto.Changeset.cast(%{
        what: "Stuff2",
        amount: Decimal.new("-2.0"),
        when: Date.from_iso8601!("2025-02-02"),
        # transaction: transaction |> Map.from_struct(),
        # member: member |> Map.from_struct(),
        expires_on: nil
      }, [:what, :amount, :when, :expires_on
      ])
      |> Ecto.Changeset.put_assoc(:transaction, transaction)
      |> Ecto.Changeset.put_assoc(:member, member)
      # |> Ecto.Changeset.put_assoc(:uses, [income1])
      |> Ecto.Changeset.put_assoc(:uses_credits_credits, [%{
        uses: income1,
        amount: Decimal.new("-2.0")
      }])
      |> Oas.Repo.insert!()

      now = Date.from_iso8601!("2025-02-02")

      credits = Oas.Credits.Credits.get_credits(member, now)
      result = credits |> Enum.reduce(Decimal.new("0.0"), fn {_, sum}, acc ->
        Decimal.add(acc, sum)
      end)
      assert Decimal.eq?(result, 3)
    end
  end
end
