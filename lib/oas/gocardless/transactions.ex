import Ecto.Query, only: [from: 2]

defmodule Oas.Gocardless.Transactions do

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
        if (is_map_key(out_transaction, :who_member_id) && out_transaction.who_member_id != nil) do
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
            if (is_map_key(out_transaction, :who_member_id) && out_transaction.who_member_id != nil) do
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

    # warning = if amount >= 0 and maybe_member == nil do
    #   true
    # else
    #   false
    # end

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

  # Oas.Gocardless.Transactions.process_transacitons()
  def process_transacitons() do

    # get last transaction
    last_transaction = from(tra in Oas.Transactions.Transaction,
      select: max(tra.when)
    ) |> Oas.Repo.one

    # {:ok, transactions, headers} = get_transactions_real(last_transaction)
    {:ok, transactions, headers} = get_transactions_mock_1(last_transaction) # DEBUG ONLY, change to get_transactions_real()

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
      generate_transaction(
        transaction
      )

      # Add transaction
    end)
    {:ok, headers}
  end

    # Oas.Gocardless.Transactions.get_transactions_real()
  def get_transactions_real(from \\ nil) do
    {:ok, access_token} = GenServer.call(Oas.Gocardless.AuthServer, :get_access_token)
    account_id = from(cc in Oas.Config.Config, select: cc.gocardless_account_id) |> Oas.Repo.one()

    query_string = if (from != nil) do
      "?date_from=#{from}"
    else
      ""
    end

    {:ok, 200, headers, client} = :hackney.request(
      :get, "https://bankaccountdata.gocardless.com/api/v2/accounts/#{account_id}/transactions/#{query_string}",
      Oas.Gocardless.get_headers(access_token)
    )
    {:ok, response_string} = :hackney.body(client)
    {:ok, data} = JSON.decode(response_string)

    {:ok, data["transactions"]["booked"], headers}
  end

  def get_transactions_mock_1(_when) do
    {:ok, [%{
      "bookingDate" => "2025-02-11",
      "bookingDateTime" => "2025-02-07T00:00:00.000Z",
      "debtorName" => "CHRISB",
      "internalTransactionId" => "1bb4606bd800c76abfebffb5a5511db0",
      "proprietaryBankTransactionCode" => "POS",
      "remittanceInformationUnstructured" => "0543 06JAN25      LV INSURANCE W    0330 1239970 GB",
      "transactionAmount" => %{"amount" => "5", "currency" => "GBP"},
      "transactionId" => "8AD4A5144E8D4C5987C0BAC4913DBD6340C9D083424B1AA5F38729B4A81C3C3E82153E637BD4BAA5CD31D80B26B2848A"
    }],
    [
      {"Date", "Sun, 16 Feb 2025 11:29:24 GMT"},
      {"Content-Type", "application/json"},
      {"Transfer-Encoding", "chunked"},
      {"Connection", "keep-alive"},
      {"vary", "Accept, Accept-Language, Cookie"},
      {"vary", "Accept-Encoding"},
      {"allow", "GET, HEAD, OPTIONS"},
      {"http_x_ratelimit_limit", "100"},
      {"http_x_ratelimit_remaining", "99"},
      {"http_x_ratelimit_reset", "59"},
      {"http_x_ratelimit_account_success_limit", "4"},
      {"http_x_ratelimit_account_success_remaining", "0"},
      {"http_x_ratelimit_account_success_reset", "86307"},
      {"Cache-Control", "no-store, no-cache, max-age=0"},
      {"x-c-uuid", "07a75933-1cbc-44e2-bd48-98cd61d08edb"},
      {"x-u-uuid", "e6913b9b-0c57-41e2-9d65-0264ffb6c276"},
      {"x-frame-options", "DENY"},
      {"content-language", "en"},
      {"x-content-type-options", "nosniff"},
      {"referrer-policy", "same-origin"},
      {"client-region", "ES"},
      {"cf-ipcountry", "GB"},
      {"strict-transport-security", "max-age=31556926; includeSubDomains;"},
      {"CF-Cache-Status", "BYPASS"},
      {"Server", "cloudflare"},
      {"CF-RAY", "912d33138a2171ec-LHR"}
    ]
    }
  end

  def get_transactions_mock_2(_when) do
    {:ok,
     [
       %{
         "bookingDate" => "2025-02-10",
         "bookingDateTime" => "2025-02-10T00:00:00.000Z",
         "internalTransactionId" => "e884c3b4c18dff7a1a754c3b1de583a1",
         "proprietaryBankTransactionCode" => "DPC",
         "remittanceInformationUnstructured" => "Albany            CHRIS BISHOP      VIA ONLINE - PYMT FP 10/02/25 10    03102227707126000N",
         "transactionAmount" => %{"amount" => "-10.00", "currency" => "GBP"},
         "transactionId" => "8AD4A5144E8D4C5987C0BAC4913DBD637C1183938B7FDEEC31BD3280DF58208B6F66AD4CDA4DBFDAEC4CD17574883600"
       },
       %{
         "bookingDate" => "2025-02-07",
         "bookingDateTime" => "2025-02-07T00:00:00.000Z",
         "creditorName" => "BENDYSTUDIO PETHERTON ROA GB",
         "internalTransactionId" => "d2c60efbb654d12b79f195dd7b79ca56",
         "proprietaryBankTransactionCode" => "POS",
         "remittanceInformationUnstructured" => "0543 06FEB25      BENDYSTUDIO       PETHERTON ROA GB",
         "transactionAmount" => %{"amount" => "-6.06", "currency" => "GBP"},
         "transactionId" => "8AD4A5144E8D4C5987C0BAC4913DBD63C64DD72D01B64EC0CDCD3879F56D2B0DFF3D22B59685E453B66353FBBA6D0E38"
       },
       %{
         "bookingDate" => "2025-02-07",
         "bookingDateTime" => "2025-02-07T00:00:00.000Z",
         "debtorName" => "CAROL BISHOP MORTGAGELOAN",
         "internalTransactionId" => "7b3ed063593ab62799ee9e4dfd982f27",
         "proprietaryBankTransactionCode" => "BAC",
         "remittanceInformationUnstructured" => "CAROL BISHOP      MORTGAGELOAN      FP 07/02/25 1232  00155663632BHWCSBB",
         "transactionAmount" => %{"amount" => "9500.00", "currency" => "GBP"},
         "transactionId" => "8AD4A5144E8D4C5987C0BAC4913DBD63C64DD72D01B64EC0CDCD3879F56D2B0DA83C63321000FFFC5D59FCD6A5CA3D11"
       },
       %{
         "bookingDate" => "2025-02-06",
         "bookingDateTime" => "2025-02-06T00:00:00.000Z",
         "debtorName" => "CAROL BISHOP MORTGAGELOAN",
         "internalTransactionId" => "ee613936ee500996af38ae3798c35992",
         "proprietaryBankTransactionCode" => "BAC",
         "remittanceInformationUnstructured" => "CAROL BISHOP      MORTGAGELOAN      FP 06/02/25 1245  00155663632BHWCCLC",
         "transactionAmount" => %{"amount" => "10000.00", "currency" => "GBP"},
         "transactionId" => "8AD4A5144E8D4C5987C0BAC4913DBD635F559F563AED0C5F56331D61D0541E76FBAB5EA3760DE90525CF86CD078B0F4E"
       },
       %{
         "bookingDate" => "2025-02-05",
         "bookingDateTime" => "2025-02-05T00:00:00.000Z",
         "internalTransactionId" => "07259d996d46e5b956c38349f64ff85b",
         "proprietaryBankTransactionCode" => "D/D",
         "remittanceInformationUnstructured" => "SANTANDER MORTGAGE",
         "transactionAmount" => %{"amount" => "-701.98", "currency" => "GBP"},
         "transactionId" => "8AD4A5144E8D4C5987C0BAC4913DBD63341720D80F633C6D3F34971EF9BD0AA733D95BA898E2398248B4784166F5598E"
       },
       %{
         "bookingDate" => "2025-02-05",
         "bookingDateTime" => "2025-02-05T00:00:00.000Z",
         "creditorName" => "GOOGLE ONE LONDON GB",
         "internalTransactionId" => "46755067d4d9dc04c812a409eac9adc4",
         "proprietaryBankTransactionCode" => "POS",
         "remittanceInformationUnstructured" => "0543 05FEB25      GOOGLE ONE        LONDON GB",
         "transactionAmount" => %{"amount" => "-7.99", "currency" => "GBP"},
         "transactionId" => "8AD4A5144E8D4C5987C0BAC4913DBD63341720D80F633C6D3F34971EF9BD0AA7A5430486BED4BA8FA26A416C484A00BF"
       }
     ]}
  end

end
