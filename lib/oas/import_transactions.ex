import Ecto.Query, only: [from: 2]

defmodule Oas.ImportTransactions do

  def processDuplicates(rows) do
    rows
    |> Enum.map(fn (row) -> 
      
      csvDate = Map.get(row, :date)

      query = from(t in Oas.Transactions.Transaction,
        where: t.when == ^csvDate
          and t.bank_details == ^Map.get(row, :account)
          and t.amount == ^Map.get(row, :amount),
        limit: 1
      )

      dupliate = Oas.Repo.one(query)

      case dupliate do
        nil -> row
        %{id: id} ->
          row
          |> Map.put(:errors, [%{name: :duplicate, transaction_id: id} | Map.get(row, :errors, [])])
      end
    end)
  end

  def processMembership(rows) do
    rows
    |> Enum.map(fn
      row when is_map_key(row, :state) -> row
      row -> 
        membershipPeriod = Oas.Members.MembershipPeriod.getThisOrNextMembershipPeriod(Map.get(row, :date))

        amount =
          Map.get(row, :amount) |> Decimal.from_float

        case membershipPeriod do
          nil -> row
          %{value: value} -> 
            cond do
              Decimal.eq?(amount, value) ->
                if (is_map_key(row, :who_member_id)) do
                  Map.put(row, :state, :membership)
                else
                  Map.put(row, :warnings, ["This looks like a membership, but related member (via bank_account_name: \"" <> row.bank_account_name <> "\") was not found" | Map.get(row, :warnings, [])])
                end
              true -> row
            end
          _ -> row
        end
    end)
  end

  def processTokens(rows) do
    rows
    |> Enum.map(fn
      row when is_map_key(row, :state) -> row
      row ->
        case Enum.find(
          Oas.Tokens.Token.getPossibleTokenAmount(),
          fn {no, value} ->
            (value * no) == Map.get(row, :amount)
          end
        ) do
          nil -> row
          {no, value} ->
            if (is_map_key(row, :who_member_id)) do
              Map.put(row, :state, :tokens) |> Map.put(:state_data, %{quantity: no, value: value})
            else
              Map.put(row, :warnings, ["This looks like tokens, but related member (via bank_account_name) was not found" | Map.get(row, :warnings, [])])
            end
        end
    end)
  end

  def processWhoMemberId(rows) do
    rows
    |> Enum.map(fn (row = %{bank_account_name: bank_account_name}) -> 
      id = from(m in Oas.Members.Member,
        where: m.bank_account_name == ^bank_account_name
      )
      |> Oas.Repo.one
      case id do
        nil -> row
        %{id: id} -> Map.put(row, :who_member_id, id)
      end
    end)
  end

  def process(rows) do
    rows
      |> processDuplicates
      |> processWhoMemberId
      |> processMembership
      |> processTokens
  end

  # -----------------------------------

  defp doTokens(%{
    who_member_id: who_member_id, 
    quantity: quantity,
    value: value,
    when1: when1
  }, result) do
    Oas.Attendance.add_tokens(%{
      member_id: who_member_id,
      transaction_id: result.id,
      quantity: quantity,
      value: value,
      when1: when1
    })
  end

  defp doMembership(%{
    who_member_id: who_member_id,
    when1: when1
  }, result) do
    # membershipPeriod = from(mp in Oas.Members.MembershipPeriod,
    #   where: (mp.from <= ^when1 and mp.to > ^Date.add(when1, 31)) or
    #     (mp.from <= ^Date.add(when1, 31) and mp.to > ^when1),
    #   limit: 1
    # )
    # |> Oas.Repo.one

    membershipPeriod = Oas.Members.MembershipPeriod.getThisOrNextMembershipPeriod(when1)

    %Oas.Members.Membership{
      transaction_id: result.id,
      member_id: who_member_id,
      membership_period_id: membershipPeriod.id
    } |> Oas.Repo.insert
  end

  def doImport(rows) do
    rows
    |> Enum.map(fn row = (%{
      account: account, # "20-65-18 13072630",
      amount: amount,
      bank_account_name: bank_account_name,
      date: date,
      memo: memo,
      my_reference: my_reference,
      transaction_tags: transaction_tags
    }) ->
      
      who = case Map.get(row, :who_member_id, nil) do
        nil -> bank_account_name
        id -> Oas.Repo.get!(Oas.Members.Member, id) |> Map.get(:name)
      end

      {:ok, result} = %Oas.Transactions.Transaction{}
      |> Oas.Transactions.Transaction.changeset(%{
        what: my_reference,
        when: date,
        who: who,
        who_member_id: Map.get(row, :who_member_id, nil),
        type: if row.amount < 0 do "OUTGOING" else "INCOMING" end,
        amount: amount,
        bank_details: bank_account_name <> "\n" <> account,
        my_reference: my_reference
      })
      |> Oas.Transactions.TransactionTags.doTransactionTags(%{transaction_tags: transaction_tags})
      |> Oas.Repo.insert

      if (Map.get(row, :state, nil) == :tokens) do
        doTokens(%{
          when1: date,
          who_member_id: Map.get(row, :who_member_id, nil),
          quantity: get_in(row, [:state_data, :quantity]),
          value: get_in(row, [:state_data, :value])
        }, result)
      end

      if (Map.get(row, :state, nil) == :membership) do
        doMembership(%{
          when1: date, 
          who_member_id: Map.get(row, :who_member_id, nil),
        }, result)
      end

      :ok
    end)

  end
end