import Ecto.Query, only: [from: 2]
defmodule Oas.Transactions.TransactionTags do
  use Ecto.Schema

  schema "transaction_tags" do
    field :name, :string

    many_to_many :transactions, Oas.Transactions.Transaction, join_through: "transaction_transaction_tags",
      join_keys: [transaction_tag_id: :id, transaction_id: :id], on_replace: :delete
    timestamps()
  end

  def changeset(struct, params) do
    struct
    |> Ecto.Changeset.cast(params, [:name])
  end

  def doTransactionTags(changeset, args) do
    case args do
      %{transaction_tags: transaction_tags} ->
        transaction_tags = transaction_tags
          |> Enum.map(fn
            %{id: id} -> Oas.Repo.get!(Oas.Transactions.TransactionTags, id)
            %{name: name} -> # attempt to find the by tag
              from(tt in Oas.Transactions.TransactionTags, where: tt.name == ^name) |> Oas.Repo.one || %{name: name}
          end)
        out = Ecto.Changeset.put_assoc(changeset, :transaction_tags, transaction_tags)
        out
      _ -> changeset
    end
  end
end
