defmodule Oas.Tokens.Token do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tokens" do
    belongs_to :transaction, Oas.Transactions.Transaction    
    belongs_to :member, Oas.Members.Member
    belongs_to :attendance, Oas.Trainings.Attendance
    field :expires_on, :date
    field :used_on, :date
    field :value, :decimal

    timestamps()
  end

  def getPossibleTokenAmount do
    [{1, 5}, {10, 4.5}, {20, 4.5}]
  end
end