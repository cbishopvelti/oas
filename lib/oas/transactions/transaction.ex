defmodule Oas.Transactions.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions" do
    field :what, :string
    field :when, :date
    field :who, :string
    belongs_to :member, Oas.Members.Member, foreign_key: :who_member_id
    field :type, :string
    field :amount, :decimal
    field :bank_details, :string
    field :notes, :string

    timestamps()
  end
end