defmodule Oas.Transactions.Gocardless do
  use Ecto.Schema
  import Ecto.Changeset

  schema "gocardless_transaction_iids" do
    belongs_to :transaction, Oas.Members.Transaction

    field :transaction_iid, :string
    field :gocardless_data, :string
    field :warnings, :string
  end

end
