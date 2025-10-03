defmodule Oas.Credits2Test do
  use Oas.DataCase

  defp doCredit(amount, when1, member) do


    transaction = %Oas.Transactions.Transaction{}
    |> Ecto.Changeset.cast(%{
      who: member.name,
      who_member_id: member.id,
      what: "Credit",
      amount: Decimal.new(amount),
      when: when1, # Date.from_iso8601!("2025-02-01"),
      type: (if amount > 0, do: "INCOMING", else: "OUTGOING"),
      my_reference: "test reference"
    }, [
      :who, :who_member_id, :what,
      :amount, :when, :type,
      :my_reference
    ])
    |> Oas.Credits.Credit.doCredit(%{amount: Decimal.new(amount)})
    |> Oas.Repo.insert!()
  end

  describe "credits" do
    # mix test --only only
    # @tag only: true
    test "Adds up credits" do
      # Ecto.Adapters.SQL.Sandbox.checkout(Oas.Repo, sandbox: false)
      %{id: member_id, name: name} = member = Oas.MembersFixtures.member_fixture()

      doCredit("5", Date.new!(2025, 5, 26), member)
      doCredit("6", Date.new!(2025, 5, 27), member)

      {_trans, total} = Oas.Credits.Credit2.get_credit_amount(%{member_id: member_id});

      assert Decimal.eq?(total, 11)
    end

    # @tag only: true
    test "Adds credits expire" do
      # Ecto.Adapters.SQL.Sandbox.checkout(Oas.Repo, sandbox: false)
      %{id: member_id, name: name} = member = Oas.MembersFixtures.member_fixture()

      doCredit("5", Date.new!(2024, 5, 1), member)

      {_trans, total} = Oas.Credits.Credit2.get_credit_amount(%{member_id: member_id});

      assert Decimal.eq?(total, 0)
    end

    # @tag only: true
    test "One expired" do
      # Ecto.Adapters.SQL.Sandbox.checkout(Oas.Repo, sandbox: false)
      %{id: member_id, name: name} = member = Oas.MembersFixtures.member_fixture()

      doCredit("5", Date.new!(2024, 5, 1), member)
      doCredit("6", Date.new!(2024, 5, 28), member)
      doCredit("-3", Date.new!(2025, 5, 14), member)

      {_trans, total} = Oas.Credits.Credit2.get_credit_amount(%{member_id: member_id}, %{now: Date.new!(2025, 5, 15)});

      assert Decimal.eq?(total, 3)
    end

    # @tag only: true
    test "One expired diff order" do
      # Ecto.Adapters.SQL.Sandbox.checkout(Oas.Repo, sandbox: false)
      %{id: member_id, name: name} = member = Oas.MembersFixtures.member_fixture()

      doCredit("5", Date.new!(2024, 5, 28), member)
      doCredit("6", Date.new!(2024, 5, 1), member)
      doCredit("-3", Date.new!(2025, 5, 14), member)

      {_trans, total} = Oas.Credits.Credit2.get_credit_amount(%{member_id: member_id}, %{now: Date.new!(2025, 5, 15)});
      assert Decimal.eq?(total, 2)
    end
  end
end
