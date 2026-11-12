defmodule Oas.Members.Import do
  @moduledoc """
  Bulk member import for onboarding a society from a spreadsheet.

  Each row is `%{name: ..., email: ..., opening_credit: ...}`, where
  `opening_credit` is optional. Every row gets an outcome:

    * `:create` - a new member will be (or was) created
    * `:skip`   - a member with that email already exists (compared trimmed
                  and case-insensitively); the existing member is left alone
    * `:error`  - the row can't be imported, with a reason

  With `dry_run: true` nothing is saved. Otherwise every `:create` row is
  inserted in one transaction, and nothing is saved if any row has an error.
  Existing members are never changed or deleted, and no email is sent.

  A created member with an opening credit above zero also gets one manual
  INCOMING transaction for that amount ("Opening balance", dated the
  society's today) carrying the credit, built the same way as the admin
  "transaction" mutation. It is saved in the same database transaction, so
  members and credits are saved or rolled back together. Skipped rows never
  get credit.
  """

  import Ecto.Query, only: [from: 2]

  alias Oas.Repo
  alias Oas.Members.Member
  alias Oas.Transactions.Transaction

  @email_format ~r/^[^\s]+@[^\s]+$/
  @credit_format ~r/^\d+(\.\d{1,2})?$/

  def run(rows, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, true)

    rows =
      rows
      |> Enum.with_index(1)
      |> Enum.map(fn {row, index} ->
        %{
          row: index,
          name: trim(Map.get(row, :name)),
          email: trim(Map.get(row, :email)),
          opening_credit: trim(Map.get(row, :opening_credit))
        }
      end)

    existing = existing_emails(rows)
    results = classify(rows, existing, dry_run)

    cond do
      dry_run -> summary(results, false)
      Enum.any?(results, &(&1.outcome == :error)) -> summary(results, false)
      true -> insert_all(results)
    end
  end

  defp trim(nil), do: ""
  defp trim(value), do: value |> to_string() |> String.trim()

  defp key(value), do: String.downcase(value)

  defp existing_emails(rows) do
    emails = rows |> Enum.map(&key(&1.email)) |> Enum.reject(&(&1 == "")) |> Enum.uniq()

    from(m in Member,
      where: fragment("lower(trim(?))", m.email) in ^emails,
      select: fragment("lower(trim(?))", m.email)
    )
    |> Repo.all()
    |> MapSet.new()
  end

  defp classify(rows, existing, dry_run) do
    {results, _seen} =
      Enum.map_reduce(rows, %{emails: %{}, names: %{}}, fn row, seen ->
        email = key(row.email)
        name = key(row.name)

        credit = parse_credit(row.opening_credit)

        {outcome, reason, changeset} =
          cond do
            row.name == "" ->
              {:error, "Missing name", nil}

            row.email == "" ->
              {:error, "Missing email", nil}

            not Regex.match?(@email_format, row.email) or String.length(row.email) > 160 ->
              {:error, "Invalid email", nil}

            credit == :error ->
              {:error, "Invalid opening credit (use a number of 0 or more, like 12.50)", nil}

            MapSet.member?(existing, email) and credit != nil ->
              {:skip, "A member with this email already exists; opening credit not added", nil}

            MapSet.member?(existing, email) ->
              {:skip, "A member with this email already exists", nil}

            Map.has_key?(seen.emails, email) ->
              {:error, "Duplicate email in file (same as row #{seen.emails[email]})", nil}

            Map.has_key?(seen.names, name) ->
              {:error, "Duplicate name in file (same as row #{seen.names[name]})", nil}

            true ->
              # Hashing is only worth doing for rows we are about to save.
              changeset =
                Oas.Members.new_member_changeset(
                  %{name: row.name, email: row.email},
                  hash_password: !dry_run
                )

              cond do
                changeset.valid? ->
                  {:create, nil, changeset}

                # The registration message is written for the public form.
                Keyword.has_key?(changeset.errors, :name) ->
                  {:error, "A member with this name already exists", nil}

                true ->
                  {:error, changeset_reason(changeset), nil}
              end
          end

        seen =
          case outcome do
            :create ->
              %{seen | emails: Map.put(seen.emails, email, row.row), names: Map.put(seen.names, name, row.row)}

            _ ->
              seen
          end

        row = %{row | opening_credit: if(credit in [nil, :error], do: nil, else: credit)}
        {Map.merge(row, %{outcome: outcome, reason: reason, changeset: changeset}), seen}
      end)

    results
  end

  # nil for blank or zero (no transaction), a positive Decimal, or :error.
  defp parse_credit(""), do: nil

  defp parse_credit(value) do
    if Regex.match?(@credit_format, value) do
      amount = Decimal.new(value)
      if Decimal.gt?(amount, 0), do: amount, else: nil
    else
      :error
    end
  end

  defp changeset_reason(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc -> String.replace(acc, "%{#{k}}", to_string(v)) end)
    end)
    |> Enum.flat_map(fn {field, messages} -> Enum.map(messages, &"#{field} #{&1}") end)
    |> Enum.join(", ")
  end

  defp insert_all(results) do
    today = Oas.Settings.today()

    transaction =
      Repo.transaction(fn ->
        Enum.map(results, fn
          %{outcome: :create, changeset: changeset} = result ->
            with {:ok, member} <- Repo.insert(changeset),
                 {:ok, transaction_id} <- insert_opening_credit(member, result.opening_credit, today) do
              Map.merge(result, %{member_id: member.id, transaction_id: transaction_id})
            else
              {:error, changeset} ->
                Repo.rollback(%{result | outcome: :error, reason: changeset_reason(changeset)})
            end

          result ->
            result
        end)
      end)

    case transaction do
      {:ok, results} ->
        summary(results, true)

      {:error, failed} ->
        results
        |> Enum.map(fn result -> if result.row == failed.row, do: failed, else: result end)
        |> summary(false)
    end
  end

  defp insert_opening_credit(_member, nil, _today), do: {:ok, nil}

  defp insert_opening_credit(member, amount, today) do
    %Transaction{}
    |> Transaction.save_changeset(%{
      what: "Opening balance",
      when: today,
      who: member.name,
      who_member_id: member.id,
      type: "INCOMING",
      amount: amount,
      my_reference: "opening-balance-member-#{member.id}",
      notes: "Opening balance from member import",
      credit: %{amount: Decimal.to_float(amount)}
    })
    |> Repo.insert()
    |> case do
      {:ok, transaction} -> {:ok, transaction.id}
      error -> error
    end
  end

  defp summary(results, saved) do
    rows = Enum.map(results, &Map.drop(&1, [:changeset]))
    count = fn outcome -> Enum.count(rows, &(&1.outcome == outcome)) end

    %{
      saved: saved,
      create_count: count.(:create),
      skip_count: count.(:skip),
      error_count: count.(:error),
      opening_credit_total:
        rows
        |> Enum.filter(&(&1.outcome == :create and &1.opening_credit != nil))
        |> Enum.reduce(Decimal.new(0), &Decimal.add(&1.opening_credit, &2)),
      rows: rows
    }
  end
end
