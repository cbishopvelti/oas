import Ecto.Query, only: [from: 2]

defmodule Oas.Gocardless.Transactions do
  require Logger

  defp is_duplicate(%{
    "bookingDate" => booking_date,
    # "transactionAmount" => %{
    #   "amount" => amount
    # },
    amount: amount,
    name: name
  }) do
    who_member = from(m in Oas.Members.Member,
      where: m.gocardless_name == ^name
    ) |> Oas.Repo.one

    who = case who_member do
      nil -> name
      who_member -> who_member |> Map.get(:name)
    end

    duplicate = from(t in Oas.Transactions.Transaction,
      where: t.when == ^booking_date
        and t.who == ^who
        and t.amount == ^amount,
      limit: 1
    ) |> Oas.Repo.one

    case duplicate do
      nil -> false
      _ -> true
    end
  end

  @dialyzer{:no_match, process_tokens: 1}
  defp process_tokens(out_transaction) when is_map_key(out_transaction, :state) do out_transaction end
  defp process_tokens(out_transaction) do
    case Enum.find(
      Oas.Tokens.Token.getPossibleTokenAmount(),
      fn %{quantity: no, value: value} ->
        Decimal.mult(value, no) == Map.get(out_transaction, :amount)
      end
    ) do
      nil -> out_transaction
      configToken = %{quantity: quantity, value: value} ->
        if is_map_key(out_transaction, :who_member_id) && out_transaction.who_member_id != nil do
          Map.put(out_transaction, :state, :tokens)
            |> Map.put(:state_data, configToken)
            |> Map.put(:tags, ["Tokens" | Map.get(out_transaction, :tags, [])])
            |> Map.put(
              :tokens,
              Oas.Attendance.add_tokens(%{
                transaction_id: nil, # TBD
                member_id: out_transaction.who_member_id,
                when1: out_transaction.when,
                value: value,
                quantity: quantity
              }, false)
            )
        else
          Map.put(
            out_transaction,
            :warnings,
            ["This looks like tokens, but related member (via bank_account_name) was not found" | (Map.get(out_transaction, :warnings, []) || [])]
          )
        end
    end
  end

  @dialyzer{:no_match, process_membership: 1}
  defp process_membership(out_transaction) when is_map_key(out_transaction, :state) do out_transaction end
  defp process_membership(out_transaction) do
    amount = Map.get(out_transaction, :amount)

    membershipPeriod = Oas.Members.MembershipPeriod.getThisOrNextMembershipPeriod(
      out_transaction.when,
      out_transaction.who_member_id,
      out_transaction.amount
    )

    case membershipPeriod do
      nil -> out_transaction
      %{value: value} ->
        cond do
          Decimal.eq?(amount, value) ->
            if is_map_key(out_transaction, :who_member_id) && out_transaction.who_member_id != nil do
              Map.put(out_transaction, :state, :membership)
              |> Map.put(:tags, ["Membership" | Map.get(out_transaction, :tags, [])])
              |> Map.put(:what, "Membership")
              |> Map.put(:membership,
                %Oas.Members.Membership{
                  # transaction_id: result.id,
                  member_id: out_transaction.who_member_id,
                  membership_period_id: membershipPeriod.id
                }
              )
            else
              Map.put(out_transaction, :warnings,
                ["This looks like a membership, but related member (via gocardless_name: \"" <> out_transaction.who <> "\") was not found" | (Map.get(out_transaction, :warnings, []) || [])])
            end
          true -> out_transaction
        end
      _ -> out_transaction
    end
  end

  defp generate_transaction(%{
    name: name,
    maybe_member: maybe_member,
    date: date,
    amount: amount
  } = in_transaction) do
    out_transaction = %Oas.Transactions.Transaction{
      what: "From gocardless",
      when: date,
      who: (maybe_member || %{}) |> Map.get(:name, name),
      who_member_id: (maybe_member || %{}) |> Map.get(:id, nil),
      type: if amount < 0 do "OUTGOING" else "INCOMING" end,
      amount: amount,
      bank_details: name,
      my_reference: Map.get(in_transaction, "remittanceInformationUnstructured")
    } |> Map.put(:tags, ["Gocardless"])

    out_transaction =
      process_membership(out_transaction)
      |> process_tokens()

    out_transaction
    |> Oas.Transactions.Transaction.changeset()
    |> Ecto.Changeset.put_assoc(:gocardless_transaction_iid, %Oas.Transactions.Gocardless{}
      |> Oas.Transactions.Gocardless.changeset(
        %{
          gocardless_data: JSON.encode!(in_transaction |> Map.drop([:name, :maybe_member, :date, :amount])),
          warnings: (case Map.get(out_transaction, :warnings, nil) do
            nil -> nil
            [] -> nil
            warnings -> JSON.encode!(warnings)
          end),
          transaction_iid: Map.get(in_transaction, "transactionId")
        }
      )
    )
    |> Oas.Transactions.TransactionTags.doTransactionTags(
      %{transaction_tags: Map.get(out_transaction, :tags, []) |> Enum.map(fn name -> %{name: name} end)
    })
    |> (&(case Ecto.assoc_loaded?(out_transaction.membership) do
      false -> &1
      true -> Ecto.Changeset.put_assoc(&1, :membership, out_transaction.membership)
    end)).()
    |> (&(case Ecto.assoc_loaded?(out_transaction.tokens) do
      false -> &1
      true ->
        Ecto.Changeset.put_assoc(&1, :tokens, out_transaction.tokens)
    end)).()
    |> Oas.Repo.insert()
  end

  # CREDITS

  # Oas.Gocardless.Transactions.process_transacitons()
  def process_transactions_2(transactions) do
    config = from(c in Oas.Config.Config,
      limit: 1
    ) |> Oas.Repo.one()

    transactions
    # PREPROCESS
    |> Enum.map(fn transaction ->
      name = Map.get(transaction, "debtorName") || Map.get(transaction, "creditorName")
      amount = Map.get(transaction, "transactionAmount") |> Map.get("amount") |> Decimal.new()
      maybe_member = from(m in Oas.Members.Member,
        where: m.gocardless_name == ^name
      ) |> Oas.Repo.one()
      date = Map.get(transaction, "bookingDate")
      transaction
      |> Map.put(:name, name)
      |> Map.put(:amount, amount)
      |> Map.put(:maybe_member, maybe_member)
      |> Map.put(:date, date |> Date.from_iso8601!())
    end)
    # FILTER DUPLICATES
    |> Enum.filter(fn transaction ->
      !is_duplicate(transaction)
    end)
    |> Enum.map(fn transaction ->
      # Check if it needs user intervention
      if (!config.credits) do
        generate_transaction(
          transaction
        )
      else
        Oas.Gocardless.TransactionsCredits
          .generate_transaction_credits(transaction)
      end
    end)
  end
  def process_transacitons() do

    # get last transaction
    last_transaction = from(tra in Oas.Transactions.Transaction,
      select: max(tra.when)
    ) |> Oas.Repo.one

    transactions = get_transactions_real(last_transaction)
    # {:ok, transactions, headers} = Oas.Gocardless.TransactionsMockData.get_transactions_mock_1(last_transaction) # DEBUG ONLY, change to get_transactions_real()

    case transactions do
      {:ok, transactions, headers} ->
        # transactions = transactions |> Enum.take(1) # DEBUG ONLY
        process_transactions_2(transactions)
        {:ok, headers}
      {:to_many_requests, _, headers} ->
        {:ok, headers}
    end
  end

  # Oas.Gocardless.Transactions.get_transactions_real()
  # Oas.Gocardless.Transactions.get_transactions_real("2025-05-01", "2025-05-31")
  def get_transactions_real(from \\ nil, to \\ nil) do
    {:ok, access_token} = GenServer.call(Oas.Gocardless.AuthServer, :get_access_token)
    account_id = from(cc in Oas.Config.Config, select: cc.gocardless_account_id) |> Oas.Repo.one()

    query = []
    query = if (from != nil) do
      query ++ ["date_from=#{from}"]
    else
      query
    end

    query = if (to != nil) do
      query ++ ["date_to=#{to}"]
    else
      query
    end

    # Logger.info("Gocardless.Transactions.process_transacitons(#{from}) starting")
    # IO.inspect("https://bankaccountdata.gocardless.com/api/v2/accounts/#{account_id}/transactions/?#{Enum.join(query, "&")}");
    # exit("TEST")

    with {:ok, 200, headers, client} <- :hackney.request(
      :get, "https://bankaccountdata.gocardless.com/api/v2/accounts/#{account_id}/transactions/?#{Enum.join(query, "&")}",
      Oas.Gocardless.get_headers(access_token)
    )
    do
      {:ok, response_string} = :hackney.body(client)
      Logger.debug(response_string)
      {:ok, data} = JSON.decode(response_string)

      store_transactions(response_string)
      Logger.info("Gocardless.Transactions.process_transacitons(#{from}) finished", data: data)

      {:ok, data["transactions"]["booked"], headers}
    else
      {:ok, 429, headers, _client} ->
        seconds_retry = List.keyfind!(headers, "http_x_ratelimit_account_success_reset", 0) |> elem(1) |> String.to_integer()
        Logger.warning("Gocardless.Transactions.process_transacitons(#{from}) failed, retrying in #{seconds_retry}s")
        {:to_many_requests, nil, headers}
    end
  end

  # Oas.Gocardless.Transactions.store_transactions("test")
  def store_transactions(data) do
    dir = Application.get_env(:oas, :gocardless_backup_dir, "./gocardless_backup")

    when1 = DateTime.utc_now() |> DateTime.to_iso8601()
    path = Path.join(dir, "transactions_" <> when1 <> ".json")

    File.write!(path, data)
  end
end
