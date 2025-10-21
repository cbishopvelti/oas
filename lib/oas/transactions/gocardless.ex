defmodule Oas.Transactions.Gocardless do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gocardless_transaction_iids" do
    belongs_to :transaction, Oas.Transactions.Transaction

    field :transaction_iid, :string
    field :gocardless_data, :string
    field :warnings, :string
  end

  def changeset(gocardless, params \\ %{}) do
    gocardless
    |> cast(params, [:transaction_iid, :gocardless_data, :warnings], empty_values: [[], nil])
    |> Ecto.Changeset.unique_constraint(
      :transaction_iid
    )
  end
end
