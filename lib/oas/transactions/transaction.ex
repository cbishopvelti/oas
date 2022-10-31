defmodule Oas.Transactions.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions" do
    field :what, :string
    field :when, :date
    field :who, :string
    belongs_to :member, Oas.Members.Member, foreign_key: :who_member_id
    field :type, :string
    field :their_reference, :string
    field :my_reference, :string
    field :amount, :decimal
    many_to_many :transaction_tags, Oas.Transactions.TransactionTags,
      join_through: "transaction_transaction_tags", join_keys: [transaction_id: :id, transaction_tag_id: :id], on_replace: :delete
    field :bank_details, :string
    field :notes, :string

    has_many :tokens, Oas.Tokens.Token, foreign_key: :transaction_id
    has_one :membership, Oas.Members.Membership, on_replace: :nilify

    timestamps()
  end

  defp validate_type(changeset) do
    case changeset do
      %{changes: %{type: "INCOMING"}} -> changeset
      %{changes: %{type: "OUTGOING"}} -> changeset
      %{changes: %{type: _}} -> add_error(changeset, :type, "Invalid type")
      _ -> changeset
    end
  end

  defp validate_amount (changeset) do
    cond do
      get_field(changeset, :type) == "INCOMING" and Decimal.to_float(get_field(changeset, :amount)) < 0 -> add_error(changeset, :amount, "Incoming transaction must be positive")
      get_field(changeset, :type) == "OUTGOING" and Decimal.to_float(get_field(changeset, :amount)) >= 0 -> add_error(changeset, :amount, "Outgoing transaction must be negative")
      true -> changeset
    end
  end

  def changeset(transaction, params \\ %{}) do
    transaction
    |> cast(params, [:what, :when, :who, :who_member_id, :type, :amount, :bank_details, :notes, :their_reference, :my_reference])
    |> validate_required([:what, :when, :who, :type, :amount])
    |> validate_type
    |> validate_amount
  end
end