defmodule Oas.Transactions.TransactionTags do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transaction_tags" do
    field :name, :string
    timestamps()
  end

  def changeset(struct, params) do
    struct
    |> Ecto.Changeset.cast(params, [:name])
  end
end