import Ecto.Query, only: [from: 2, where: 3]
defmodule OasWeb.Schema.SchemaAnalysis do
  use Absinthe.Schema.Notation

  object :analysis do
    field :transactions_income, :float
    field :transactions_outgoing, :float
    field :unused_tokens, :integer
    field :unused_tokens_amount, :float
  end

  object :analysis_queries do
    field :analysis, :analysis do
      arg :from, non_null(:string)
      arg :to, non_null(:string)
      resolve fn _, %{from: from, to: to}, _ ->
        from = Date.from_iso8601!(from)
        to = Date.from_iso8601!(to)

        transactions_income = from(t in Oas.Transactions.Transaction,
          where: t.when >= ^from and t.when <= ^to and t.type == "INCOMING",
          select: sum(t.amount)
        ) |> Oas.Repo.one! || Decimal.new(0)
      
        transactions_outgoing = from(t in Oas.Transactions.Transaction,
          where: t.when >= ^from and t.when <= ^to and t.type == "OUTGOING",
          select: sum(t.amount)
        ) |> Oas.Repo.one! || Decimal.new(0)

        unused_tokens = from(t in Oas.Tokens.Token,
          select: count(t.id),
          where: t.expires_on > ^to and is_nil(t.used_on)
        ) |> Oas.Repo.one!

        unused_tokens_amount = from(t in Oas.Tokens.Token,
          where: t.expires_on > ^to and is_nil(t.used_on),
          select: sum(t.value)
        ) |> Oas.Repo.one

        {:ok, %{
          transactions_income: transactions_income |> Decimal.to_float,
          transactions_outgoing: transactions_outgoing |> Decimal.to_float,
          unused_tokens: unused_tokens,
          unused_tokens_amount: (unused_tokens_amount || Decimal.new(0)) |> Decimal.to_float
        }}
      end
    end
  end
end