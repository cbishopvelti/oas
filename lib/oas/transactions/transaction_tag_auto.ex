import Ecto.Query, only: [from: 2]
defmodule Oas.Transactions.TransactionTagAuto do
  use Ecto.Schema

  schema "transaction_tag_auto" do
    field :who, :string
    belongs_to :transaction_tag, Oas.Transactions.TransactionTags

    timestamps()
  end



  def do_auto_tags(old_who, who, transaction_tags, auto_tags) do
    IO.inspect(old_who, label: "001 old_who")
    IO.inspect(who, label: "001.1 who")
    IO.inspect(transaction_tags, label: "001.2 transaction_tags")
    IO.inspect(auto_tags, label: "001.3, auto_tags")

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    auto_tags = auto_tags
    |> Enum.map(fn %{id: _id} = tag -> tag
      %{name: name} -> transaction_tags |> Enum.find(fn %{name: nam} -> nam == name end)
    end)


    # Delete
    if (old_who !== who) do
      case from(tr in Oas.Transactions.Transaction,
        where: tr.who == ^old_who
      ) |> Oas.Repo.exists?() do
        true -> # Old still exist, delete relevent tags

          from(ta in Oas.Transactions.TransactionTagAuto,
            where: (ta.who == ^old_who or ta.who == ^who)
            and not(ta.transaction_tag_id in ^(auto_tags |> Enum.map(fn %{id: id} -> id end)))
            and ta.transaction_tag_id in ^(transaction_tags |> Enum.map(fn %{id: id} -> id end))
          ) |> Oas.Repo.delete_all()

        false -> # No old who remaining, so delete all transaciton tags from old
          from(ta in Oas.Transactions.TransactionTagAuto,
            where: ta.who == ^old_who
          )
      end
    else # old_who == who

      from(ta in Oas.Transactions.TransactionTagAuto,
        where: ta.who == ^who
        and not(ta.transaction_tag_id in ^(auto_tags |> Enum.map(fn %{id: id} -> id end)))
        and ta.transaction_tag_id in ^(transaction_tags |> Enum.map(fn %{id: id} -> id end))
      ) |> Oas.Repo.delete_all()
    end

    Oas.Repo.insert_all(Oas.Transactions.TransactionTagAuto, auto_tags |> Enum.map(fn %{id: id} ->
      %{
        transaction_tag_id: id,
        who: who,
        inserted_at: now,
        updated_at: now
      }
    end), on_conflict: :nothing)

  end
end
