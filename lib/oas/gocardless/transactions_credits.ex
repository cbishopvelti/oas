import Ecto.Query, only: [from: 2]

defmodule Oas.Gocardless.TransactionsCredits do


  # No member id, so do nothing
  defp process_credits(
    changeset, data
  ) do
    case Ecto.Changeset.fetch_field(changeset, :who_member_id) do
      :error -> {changeset, data}
      _ -> process_credits_2(changeset, data)
    end
  end
  defp process_credits_2(changeset, data) do
    config = from(cc in Oas.Config.Config, select: cc) |> Oas.Repo.one
    configToken = case Oas.Attendance.get_token_amount(%{member_id: Ecto.Changeset.get_field(changeset, :who_member_id)}) do
      x when x < 0 ->
        configTokens = Oas.Tokens.Token.getPossibleTokenAmount()
        |> Enum.sort_by(fn %{value: value} -> value |> Decimal.to_float() end, :asc)

        configToken = configTokens |> Enum.filter(fn %{quantity: no, value: value} ->
          (no * Decimal.to_float(value)) <= (Ecto.Changeset.get_field(changeset, :amount) |> Decimal.to_float())
        end)
        |> List.first()
        configToken = configToken || configTokens |> List.last()

        # Can only buy the amount of outstanding tokens if you've payed enough to cover them.
        amount = Ecto.Changeset.get_field(changeset, :amount)
        max_num = Decimal.div(amount, configToken.value) |> Decimal.round(0, :floor)
          |> Decimal.to_integer()
        outstanding = abs(x)

        %{configToken | quantity: min(max_num, outstanding)}
      _ -> nil
    end

    case configToken do
      nil ->
        changeset = changeset
        |> Ecto.Changeset.put_assoc(:credit, %{
          when: Ecto.Changeset.get_field(changeset, :when),
          what: "Transaction (Gocardless)",
          who_member_id: Ecto.Changeset.get_field(changeset, :who_member_id),
          amount: Ecto.Changeset.get_field(changeset, :amount),
          expires_on: Date.add(changeset |> Ecto.Changeset.get_field(:when), config.token_expiry_days)
        })
        data = %{data | transaction_tags: ["Credits" | data.transaction_tags]}
        {changeset, data}
      configToken ->
        cond do
          (Decimal.to_float(configToken.value) * configToken.quantity) ==
            (Ecto.Changeset.get_field(changeset, :amount) |> Decimal.to_float())
          ->
            changeset = changeset |>
              Oas.Attendance.add_tokens_changeset(%{
                member_id: changeset |> Ecto.Changeset.get_field(:who_member_id),
                value: configToken.value,
                quantity: configToken.quantity,
                when1: changeset |> Ecto.Changeset.get_field(:when)
              })
            data = %{data | transaction_tags: ["Tokens" | data.transaction_tags]}
            {changeset, data}
          true ->
            changeset = changeset
            |> Ecto.Changeset.put_assoc(:credit, %{
              when: Ecto.Changeset.get_field(changeset, :when),
              what: "Transaction (Gocardless)",
              who_member_id: Ecto.Changeset.get_field(changeset, :who_member_id),
              amount: Decimal.sub(
                Ecto.Changeset.get_field(changeset, :amount),
                Decimal.mult(configToken.value, configToken.quantity)
              ),
              expires_on: Date.add(changeset |> Ecto.Changeset.get_field(:when), config.token_expiry_days)
            })
            |> Oas.Attendance.add_tokens_changeset(%{
              member_id: changeset |> Ecto.Changeset.get_field(:who_member_id),
              value: configToken.value,
              quantity: configToken.quantity,
              when1: changeset |> Ecto.Changeset.get_field(:when)
            })

            data = %{data | transaction_tags: ["Tokens", "Credits" | data.transaction_tags]}
            {changeset, data}
        end
    end
  end

  def generate_transaction_credits_2(changeset, data) do
    {out_changeset, data} = case Ecto.Changeset.get_field(changeset, :who_member_id) do
      who_member_id when is_integer(who_member_id) ->
        changeset
        |> process_credits(data)
      _ -> {changeset, data}
    end

    out_changeset = out_changeset
    |> Oas.Transactions.TransactionTags.doTransactionTags(
      %{transaction_tags: Map.get(data, :transaction_tags, []) |> Enum.map(fn tag -> %{name: tag} end)
    })

    out_changeset
  end

  def generate_transaction_credits(%{
    name: name,
    maybe_member: maybe_member,
    maybe_training_where: maybe_training_where,
    date: date,
    amount: amount
  } = in_transaction) do

    out_transaction = Oas.Transactions.Transaction.changeset(
      %Oas.Transactions.Transaction{},
      %{
        what: "From gocardless",
        when: date,
        who: (maybe_member || maybe_training_where || %{}) |> Map.get(:name, name),
        who_member_id: (maybe_member || %{}) |> Map.get(:id, nil),
        training_where_id: (maybe_training_where || %{}) |> Map.get(:id, nil),
        type: if Decimal.lt?(amount, "0.0") do "OUTGOING" else "INCOMING" end,
        amount: amount,
        bank_details: name,
        my_reference: Map.get(in_transaction, "remittanceInformationUnstructured")
      }
    )

    auto_tags = Oas.Transactions.TransactionTagAuto.get_auto_tags(
      Map.get(out_transaction.changes, :who),
      Map.get(out_transaction.changes, :who_member_id, nil)
    ) |> Enum.map(fn %{name: name} -> name end)

    auto_tags = case maybe_training_where do
      nil -> auto_tags
      _ -> ["Venue" | auto_tags]
    end

    data = %{
      transaction_tags: ["Gocardless" | auto_tags] |> Enum.uniq()
    }

    out_changeset = generate_transaction_credits_2(out_transaction, data)

    # Go cardless
    out_changeset = out_changeset
    |> Ecto.Changeset.put_assoc(:gocardless_transaction_iid, %Oas.Transactions.Gocardless{}
      |> Oas.Transactions.Gocardless.changeset(
        %{
          gocardless_data: JSON.encode!(in_transaction |> Map.drop([:name, :maybe_member, :maybe_training_where, :date, :amount])),
          warnings: (case Map.get(out_transaction, :warnings, nil) do
            nil -> nil
            [] -> nil
            warnings -> JSON.encode!(warnings)
          end),
          transaction_iid: Map.get(in_transaction, "transactionId")
        }
      )
    )

    out_changeset |> Oas.Repo.insert()
    :ok
  end
end
