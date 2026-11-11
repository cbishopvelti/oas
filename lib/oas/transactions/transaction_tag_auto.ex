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

  # Returns {:ok, inserted_count}.
  #
  # An auto tag that isn't one of the transaction's tags is ignored, whether
  # it came with an id or only a name: the admin form keeps a tag in
  # auto_tags after it has been removed from the transaction.
  def do_auto_tags(old_who, who, transaction_tags, auto_tags) do
    auto_tags = auto_tags
    |> Enum.map(fn %{id: id} = tag when not is_nil(id) -> tag
      %{name: name} -> Enum.find(transaction_tags, fn %{name: nam} -> nam == name end)
    end)
    |> Enum.reject(&is_nil/1)

    do_auto_tags_checked(old_who, who, transaction_tags, auto_tags)
  end

  defp do_auto_tags_checked(old_who, who, transaction_tags, auto_tags) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    # A new transaction has no old who; comparing a column with nil raises.
    old_who = old_who || who

    renamed = old_who !== who
    old_who_remains = renamed and (from(tr in Oas.Transactions.Transaction,
      where: tr.who == ^old_who
    ) |> Oas.Repo.exists?())

    # The transaction was renamed and no other transaction has the old who,
    # so nothing can match the old who's auto tags any more: delete them all.
    if renamed and not old_who_remains do
      from(ta in Oas.Transactions.TransactionTagAuto,
        where: ta.who == ^old_who
      ) |> Oas.Repo.delete_all()
    end

    # Delete the auto tags that were switched off on this transaction, for the
    # who and, when other transactions still use it, the old who.
    whos = if old_who_remains, do: [old_who, who], else: [who]

    from(ta in Oas.Transactions.TransactionTagAuto,
      where: ta.who in ^whos
      and not(ta.transaction_tag_id in ^(auto_tags |> Enum.map(fn %{id: id} -> id end)))
      and ta.transaction_tag_id in ^(transaction_tags |> Enum.map(fn %{id: id} -> id end))
    ) |> Oas.Repo.delete_all()

    still_exists = MapSet.intersection(
      MapSet.new(transaction_tags |> Enum.map(fn %{id: id} -> id end)),
      MapSet.new(auto_tags |> Enum.map(fn %{id: id} -> id end))
    )

    {count, _} = Oas.Repo.insert_all(Oas.Transactions.TransactionTagAuto, auto_tags
    |> Enum.filter(fn %{id: id} -> MapSet.member?(still_exists, id) end)
    |> Enum.map(fn %{id: id} ->
      %{
        transaction_tag_id: id,
        who: who,
        inserted_at: now,
        updated_at: now
      }
    end), on_conflict: :nothing)

    {:ok, count}
  end
end
