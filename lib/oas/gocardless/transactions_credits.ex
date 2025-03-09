defmodule Oas.Gocardless.TransactionsCredits do


  # No member id, so do nothing
  defp process_credits(
    changeset, data
  ) do
    case Ecto.Changeset.fetch_field(changeset, :who_member_id) do
      nil -> {changeset, data}
      _ -> process_credits_2(changeset, data)
    end
  end
  defp process_credits_2(changeset, data) do
    configToken = case Oas.Attendance.get_token_amount(%{member_id: Ecto.Changeset.get_field(changeset, :who_member_id)}) do
      x when x < 0 ->
        configToken = Oas.Tokens.Token.getPossibleTokenAmount()
        |> Enum.sort_by(fn %{value: value} -> value |> Decimal.to_float() end, :asc)
        |> Enum.filter(fn %{quantity: no, value: value} ->
          (no * Decimal.to_float(value)) <= (Ecto.Changeset.get_field(changeset, :amount) |> Decimal.to_float())
        end)
        |> List.first()
        %{configToken | quantity: abs(x)}
      _ -> nil
    end

    case configToken do
      nil ->
        changeset = changeset
        |> Ecto.Changeset.put_assoc(:credit, %{
          when: Ecto.Changeset.get_field(changeset, :when),
          what: "Transaction (Gocardless)",
          who_member_id: Ecto.Changeset.get_field(changeset, :who_member_id),
          amount: Ecto.Changeset.get_field(changeset, :amount)
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
              )
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

  def generate_transaction_credits(%{
    name: name,
    maybe_member: maybe_member,
    date: date,
    amount: amount
  } = in_transaction) do
    IO.inspect(maybe_member, label: "001")
    out_transaction = Oas.Transactions.Transaction.changeset(
      %Oas.Transactions.Transaction{},
      %{
        what: "From gocardless",
        when: date,
        who: (maybe_member || %{}) |> Map.get(:name, name),
        who_member_id: (maybe_member || %{}) |> Map.get(:id, nil),
        type: if amount < 0 do "OUTGOING" else "INCOMING" end,
        amount: amount,
        bank_details: name,
        my_reference: Map.get(in_transaction, "remittanceInformationUnstructured")
      }
    )

    data = %{transaction_tags: ["Gocradless"]}

    {out_changeset, data} = out_transaction
    |> process_credits(data)

    out_changeset = out_changeset
    |> Oas.Transactions.TransactionTags.doTransactionTags(
      %{transaction_tags: Map.get(data, :transaction_tags, []) |> Enum.map(fn tag -> %{name: tag} end)
    })

    # Go cardless
    out_changeset = out_changeset
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

    IO.inspect(out_changeset.changes, label: "005")

    result = out_changeset |> Oas.Repo.insert()
    IO.inspect(result, label: "006")
    :ok
  end
end
