import Ecto.Query, only: [from: 2]
defmodule Oas.Transactions.TransactionTagAuto do
  use Ecto.Schema

  schema "transaction_tag_auto" do
    field :who, :string
    belongs_to :transaction_tag, Oas.Transactions.TransactionTags

    timestamps()
  end


  def get_auto_tags(who, nil) do
    from(
      tt in Oas.Transactions.TransactionTags,
      inner_join: ta in assoc(tt, :transaction_tag_auto),
      where: ta.who == ^who
    ) |> Oas.Repo.all()
  end
  def get_auto_tags(_, _) do
    []
  end

  def do_auto_tags(old_who, who, transaction_tags, auto_tags) do
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

    still_exists = MapSet.intersection(
      MapSet.new(transaction_tags |> Enum.map(fn %{id: id} -> id end)),
      MapSet.new(auto_tags |> Enum.map(fn %{id: id} -> id end))
    )

    Oas.Repo.insert_all(Oas.Transactions.TransactionTagAuto, auto_tags
    |> Enum.filter(fn %{id: id} -> MapSet.member?(still_exists, id) end)
    |> Enum.map(fn %{id: id} ->
      %{
        transaction_tag_id: id,
        who: who,
        inserted_at: now,
        updated_at: now
      }
    end), on_conflict: :nothing)
  end
end
