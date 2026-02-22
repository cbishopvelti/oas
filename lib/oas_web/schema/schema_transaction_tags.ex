import Ecto.Query, only: [from: 2]

defmodule OasWeb.Schema.SchemaTransactionTags do
  use Absinthe.Schema.Notation

  object :transaction_tags_queries do
    field :transactions_tags, list_of(:transaction_tag) do
      arg(:transaction_ids, non_null(list_of(non_null(:integer))))

      resolve(fn _, %{transaction_ids: transaction_ids}, _ ->
        required_count = length(transaction_ids)

        data =
          from(tt in Oas.Transactions.TransactionTags,
            inner_join: tr in assoc(tt, :transactions),
            where: tr.id in ^transaction_ids,
            group_by: tt.id,
            having: count(tr.id) == ^required_count,
            select: tt
          )
          |> Oas.Repo.all()

        {:ok, data}
      end)
    end
  end

  object :transaction_tags_mutations do
    field :transactions_tags, list_of(:transaction_tag) do
      arg(:transaction_ids, non_null(list_of(non_null(:integer))))
      arg(:transaction_tags, list_of(:transaction_tag_arg))

      resolve(fn _, %{transaction_ids: transaction_ids, transaction_tags: transaction_tags}, _ ->
        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        trans =
          from(tr in Oas.Transactions.Transaction,
            left_join: tt in assoc(tr, :transaction_tags),
            preload: [transaction_tags: tt],
            where: tr.id in ^transaction_ids
          )
          |> Oas.Repo.all()

        new_tags =
          transaction_tags
          |> Enum.filter(fn
            %{id: id} when not is_nil(id) -> false
            %{} -> true
          end)
          |> Enum.map(fn tag ->
            tag
            |> Map.merge(%{
              updated_at: now,
              inserted_at: now
            })
          end)
          |> (&Ecto.Multi.insert_all(
                Ecto.Multi.new(),
                :new_tags,
                Oas.Transactions.TransactionTags,
                &1,
                returning: true
              )).()

        multi =
          new_tags
          |> Ecto.Multi.merge(fn %{new_tags: {_count, new_tags}} ->
            tags =
              new_tags ++
                (transaction_tags
                 |> Enum.filter(fn
                   %{id: id} when not is_nil(id) -> true
                   %{} -> false
                 end))

            Enum.reduce(trans, Ecto.Multi.new(), fn transaction, multi_acc ->
              changeset =
                transaction
                |> Ecto.Changeset.change()
                |> Oas.Transactions.TransactionTags.doTransactionTags(%{transaction_tags: tags})

              Ecto.Multi.update(multi_acc, {:update, transaction.id}, changeset)
            end)
          end)

        {:ok, _} = Oas.Repo.transaction(multi)

        # Delete unused tags
        from(
          tt in Oas.Transactions.TransactionTags,
          as: :transaction_tags,
          where:
            not exists(
              from(
                c in "transaction_transaction_tags",
                where: c.transaction_tag_id == parent_as(:transaction_tags).id,
                select: 1
              )
            )
        )
        |> Oas.Repo.delete_all()

        # EO Delete unused tags

        {:ok, []}
      end)
    end
  end
end
