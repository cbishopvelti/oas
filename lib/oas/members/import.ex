defmodule Oas.Members.Import do
  @moduledoc """
  Bulk member import for onboarding a society from a spreadsheet.

  Each row is `%{name: ..., email: ...}`. Every row gets an outcome:

    * `:create` - a new member will be (or was) created
    * `:skip`   - a member with that email already exists (compared trimmed
                  and case-insensitively); the existing member is left alone
    * `:error`  - the row can't be imported, with a reason

  With `dry_run: true` nothing is saved. Otherwise every `:create` row is
  inserted in one transaction, and nothing is saved if any row has an error.
  Existing members are never changed or deleted, and no email is sent.
  """

  import Ecto.Query, only: [from: 2]

  alias Oas.Repo
  alias Oas.Members.Member

  @email_format ~r/^[^\s]+@[^\s]+$/

  def run(rows, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, true)

    rows =
      rows
      |> Enum.with_index(1)
      |> Enum.map(fn {row, index} ->
        %{
          row: index,
          name: trim(Map.get(row, :name)),
          email: trim(Map.get(row, :email))
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

        {outcome, reason, changeset} =
          cond do
            row.name == "" ->
              {:error, "Missing name", nil}

            row.email == "" ->
              {:error, "Missing email", nil}

            not Regex.match?(@email_format, row.email) or String.length(row.email) > 160 ->
              {:error, "Invalid email", nil}

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

        {Map.merge(row, %{outcome: outcome, reason: reason, changeset: changeset}), seen}
      end)

    results
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
    transaction =
      Repo.transaction(fn ->
        Enum.map(results, fn
          %{outcome: :create, changeset: changeset} = result ->
            case Repo.insert(changeset) do
              {:ok, member} ->
                Map.put(result, :member_id, member.id)

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

  defp summary(results, saved) do
    rows = Enum.map(results, &Map.drop(&1, [:changeset]))
    count = fn outcome -> Enum.count(rows, &(&1.outcome == outcome)) end

    %{
      saved: saved,
      create_count: count.(:create),
      skip_count: count.(:skip),
      error_count: count.(:error),
      rows: rows
    }
  end
end
