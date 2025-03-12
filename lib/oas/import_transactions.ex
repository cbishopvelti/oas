import Ecto.Query, only: [from: 2]

defmodule Oas.ImportTransactions do

  def processDuplicates(rows) do
    rows
    |> Enum.map(fn (row = %{
      bank_account_name: bank_account_name
    }) ->

      csvDate = Map.get(row, :date)

      # bank_details = Map.get(row, :bank_account_name) <> "\n" <> Map.get(row, :account)

      who = case Map.get(row, :who_member_id, nil) do
        nil -> bank_account_name
        id -> Oas.Repo.get!(Oas.Members.Member, id) |> Map.get(:name)
      end

      query = from(t in Oas.Transactions.Transaction,
        where: t.when == ^csvDate
          and t.who == ^who
          and t.amount == ^Map.get(row, :amount),
        limit: 1
      )

      # queryString = Oas.Repo.to_sql(:all, query)

      dupliate = Oas.Repo.one(query)

      case dupliate do
        nil -> row
        %{id: id} ->
          row
          |> Map.put(:errors, [%{name: :duplicate, transaction_id: id} | Map.get(row, :errors, [])])
          |> Map.put(:to_import, false)
      end
    end)
  end

  def processMembership(rows) do
    rows
    |> Enum.map(fn
      row when is_map_key(row, :state) -> row
      row ->
        amount =
          Map.get(row, :amount) |> Decimal.from_float

        membershipPeriod = Oas.Members.MembershipPeriod.getThisOrNextMembershipPeriod(
          Map.get(row, :date),
          Map.get(row, :who_member_id),
          amount
        )

        amount =
          Map.get(row, :amount) |> Decimal.from_float

        case membershipPeriod do
          nil -> row
          %{value: value} ->
            cond do
              Decimal.eq?(amount, value) ->
                if (is_map_key(row, :who_member_id)) do
                  Map.put(row, :state, :membership)
                  |> Map.put(:tags, ["Membership" | Map.get(row, :tags, [])])
                  |> (&(case row do
                    %{warnings: _} -> row
                    %{errors: _} -> row
                    _ -> Map.put(&1, :to_import, true)
                  end)).()
                else
                  Map.put(row, :warnings, ["This looks like a membership, but related member (via bank_account_name: \"" <> row.bank_account_name <> "\") was not found" | Map.get(row, :warnings, [])])
                end
              true -> row
            end
          _ -> row
        end
    end)
  end

  def processCredits(rows) do
    # If there is token debt, pay that off first
    rows |> Enum.map(fn
      row when is_map_key(row, :state) -> row
      row ->
        if (is_map_key(row, :who_member_id)) do
          # configToken = Oas.Tokens.Token.getPossibleTokenAmount()
          # |> Enum.filter(fn %{quantity: no, value: value} ->
          #   no * value <= Map.get(row, :amount)
          # end)
          # |> List.last()

          configToken = case Oas.Attendance.get_token_amount(%{member_id: Map.get(row, :who_member_id)}) do
            x when x < 0 ->
              configToken = Oas.Tokens.Token.getPossibleTokenAmount()
              |> Enum.sort_by(fn %{value: value} -> value |> Decimal.to_float() end, :asc)
              |> Enum.filter(fn %{quantity: no, value: value} ->
                (no * Decimal.to_float(value)) <= Map.get(row, :amount)
              end)
              |> List.first()
              %{configToken | quantity: abs(x)}
            _ -> nil
          end

          case configToken do
            nil ->
              Map.put(row, :state, :credits)
              |> Map.put(:tags, ["Credits" | Map.get(row, :tags, [])])
              |> (&(case row do
                %{warnings: _} -> row
                %{errors: _} -> row
                _ -> Map.put(&1, :to_import, true)
              end)).()
            configToken ->
              cond do
                Decimal.to_float(configToken.value) * configToken.quantity == Map.get(row, :amount) ->
                  Map.put(row, :state, :tokens)
                  |> Map.put(:state_data, configToken)
                  |> Map.put(:tags, ["Tokens" | Map.get(row, :tags, [])])
                  |> (&(case row do
                    %{warnings: _} -> row
                    %{errors: _} -> row
                    _ -> Map.put(&1, :to_import, true)
                  end)).()
                true ->
                  Map.put(row, :state, :tokens_credits)
                  |> Map.put(:state_data, configToken)
                  |> Map.put(:tags, ["Tokens" , "Credits" | Map.get(row, :tags, [])])
                  |> (&(case row do
                    %{warnings: _} -> row
                    %{errors: _} -> row
                    _ -> Map.put(&1, :to_import, true)
                  end)).()
              end
          end
        else
          Map.put(row, :warnings, ["Didn't find member (via bank_account_name), so not adding credits" | Map.get(row, :warnings, [])])
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
          fn %{quantity: no, value: value} ->
            ((value |> Decimal.to_float) * no) == Map.get(row, :amount)
          end
        ) do
          nil -> row
          configToken = %{quantity: _no, value: _value} ->
            if (is_map_key(row, :who_member_id)) do
              Map.put(row, :state, :tokens)
                |> Map.put(:state_data, configToken)
                |> Map.put(:tags, ["Tokens" | Map.get(row, :tags, [])])
                |> (&(case row do
                  %{warnings: _} -> row
                  %{errors: _} -> row
                  _ -> Map.put(&1, :to_import, true)
                end)).()
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
        nil -> Map.delete(row, :who_member_id)
        %{id: id} -> Map.put(row, :who_member_id, id)
      end
    end)
  end

  def processOther(rows) do
    rows
    |> Enum.map(fn
      (row = %{state: _}) -> row
      (row = %{errors: _}) -> row
      (row = %{warnings: _}) -> row
      (row) when is_map_key(row, :to_import) == false -> Map.put(row, :to_import, :true)
      row -> row
    end)
  end

  def process(rows) do
    config = from(c in Oas.Config.Config, limit: 1) |> Oas.Repo.one!()

    case config.credits do
      false ->
        rows
          |> processWhoMemberId
          |> processDuplicates
          |> processMembership
          |> processTokens
          # |> processCredits
          |> processOther
      true ->
        rows
          |> processWhoMemberId
          |> processDuplicates
          |> processCredits
          |> processOther
    end
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

  defp doCredits(%{
    who_member_id: who_member_id,
    when1: when1,
    value: value
  }, result) do
    result = result |> Oas.Repo.preload(:credit)

    Oas.Credits.Credit.doCredit(
      result |> Ecto.Changeset.change(),
      %{
        amount: value
      }
    )
    |> Oas.Repo.update()
  end

  defp doMembership(%{
    who_member_id: who_member_id,
    when1: when1,
    amount: amount
  }, result) do
    # membershipPeriod = from(mp in Oas.Members.MembershipPeriod,
    #   where: (mp.from <= ^when1 and mp.to > ^Date.add(when1, 31)) or
    #     (mp.from <= ^Date.add(when1, 31) and mp.to > ^when1),
    #   limit: 1
    # )
    # |> Oas.Repo.one

    membershipPeriod = Oas.Members.MembershipPeriod.getThisOrNextMembershipPeriod(when1, who_member_id, amount)

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
      memo: _memo,
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

      if (Map.get(row, :state, nil) == :tokens || Map.get(row, :state, nil) == :tokens_credits) do
        doTokens(%{
          when1: date,
          who_member_id: Map.get(row, :who_member_id, nil),
          quantity: get_in(row, [:state_data]) |> Map.get(:quantity),
          value: get_in(row, [:state_data]) |> Map.get(:value)
        }, result)
      end

      if (Map.get(row, :state, nil) == :credits || Map.get(row, :state, nil) == :tokens_credits) do
        doCredits(%{
          when1: date,
          who_member_id: Map.get(row, :who_member_id, nil),
          value: (amount - ((Map.get(row, :state_data, %{}) |> Map.get(:value, 0) |> Decimal.to_float()) * (Map.get(row, :state_data, %{}) |> Map.get(:quantity, 0))))
        }, result)
      end

      # if (Map.get(row, :state, nil) == :membership) do
      #   doMembership(%{
      #     when1: date,
      #     who_member_id: Map.get(row, :who_member_id, nil),
      #     amount: amount
      #   }, result)
      # end
      :ok
    end)

  end
end
