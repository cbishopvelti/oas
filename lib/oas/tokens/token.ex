import Ecto.Query, only: [from: 2]

defmodule Oas.Tokens.Token do
  use Ecto.Schema

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
    from(tk in Oas.Config.Tokens, select: tk,
      order_by: [desc: :value]
    )
      |> Oas.Repo.all

    # [{1, 5}, {10, 4.5}, {20, 4.5}]
  end
end
