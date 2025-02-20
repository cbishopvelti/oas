defmodule Oas.TransactionFixtures do
  def transaction_fixture(_attrs \\ %{}) do
    %{id: member_id, name: name} = member = Oas.MembersFixtures.member_fixture()

    transaction = %Oas.Transactions.Transaction{}
    |> Ecto.Changeset.cast(%{
      who: name,
      who_member_id: member_id,
      what: "Credit",
      amount: Decimal.new("5.0"),
      when: Date.from_iso8601!("2025-02-01"),
      type: "INCOMING",
      my_reference: "test reference"
    }, [
      :who, :who_member_id, :what,
      :amount, :when, :type,
      :my_reference
    ]) |> Oas.Repo.insert!()

    {transaction, member}
  end
end
