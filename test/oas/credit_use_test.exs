defmodule Oas.CreditUseTest do
  use Oas.DataCase

  defp credit!(member, attrs) do
    %Oas.Credits.Credit{}
    |> Ecto.Changeset.cast(
      Map.merge(%{what: "test", who_member_id: member.id}, attrs),
      [:what, :amount, :when, :who_member_id, :membership_id, :thing_id, :transaction_id, :credit_id]
    )
    |> Oas.Repo.insert!()
  end

  test "get_credit_use groups spent credits by what they were spent on" do
    {transaction, member} = Oas.TransactionFixtures.transaction_fixture()
    other_member = Oas.MembersFixtures.member_fixture()

    period =
      %Oas.Members.MembershipPeriod{name: "2025", value: Decimal.new("12"),
        from: ~D[2025-01-01], to: ~D[2025-12-31]}
      |> Oas.Repo.insert!()

    membership =
      %Oas.Members.Membership{member_id: member.id, membership_period_id: period.id}
      |> Oas.Repo.insert!()

    thing = %Oas.Things.Thing{what: "T-shirt", value: Decimal.new("20"), when: ~D[2025-03-01]}
      |> Oas.Repo.insert!()

    # Positive credit: purchase, never counted as use
    credit!(member, %{amount: Decimal.new("100"), when: ~D[2025-01-05], transaction_id: transaction.id})

    credit!(member, %{amount: Decimal.new("-12"), when: ~D[2025-02-01], membership_id: membership.id})
    credit!(member, %{amount: Decimal.new("-20"), when: ~D[2025-03-01], thing_id: thing.id})
    credit!(member, %{amount: Decimal.new("-4.5"), when: ~D[2025-04-01], transaction_id: transaction.id})
    credit!(member, %{amount: Decimal.new("-1"), when: ~D[2025-05-01]})

    # Transfer: the receiving member's positive credit points at the debit
    debit = credit!(member, %{amount: Decimal.new("-7"), when: ~D[2025-06-01], what: "To other"})
    credit!(other_member, %{amount: Decimal.new("7"), when: ~D[2025-06-01], what: "From member", credit_id: debit.id})

    # Outside the range
    credit!(member, %{amount: Decimal.new("-12"), when: ~D[2024-12-31], membership_id: membership.id})
    credit!(member, %{amount: Decimal.new("-12"), when: ~D[2026-01-01], membership_id: membership.id})

    out = Oas.Credits.Credit.get_credit_use(~D[2025-01-01], ~D[2025-12-31])

    assert Decimal.eq?(out.membership, "12")
    assert Decimal.eq?(out.attendance, "0")
    assert Decimal.eq?(out.things, "20")
    assert Decimal.eq?(out.refunds, "4.5")
    assert Decimal.eq?(out.other, "1")
    assert Decimal.eq?(out.transfers, "7")
    # Transfers are not "used", so they are excluded from the total
    assert Decimal.eq?(out.total, "37.5")

    # Inclusive boundaries
    out = Oas.Credits.Credit.get_credit_use(~D[2024-12-31], ~D[2026-01-01])
    assert Decimal.eq?(out.membership, "36")
  end
end
