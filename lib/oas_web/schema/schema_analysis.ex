import Ecto.Query, only: [from: 2]

defmodule OasWeb.Schema.SchemaAnalysis do
  use Absinthe.Schema.Notation

  object :analysis do
    field :transactions_income, :float
    field :transactions_outgoing, :float
    field :transactions_difference, :float
    field :unused_tokens, :integer
    field :unused_tokens_amount, :float
    field :transactions_ballance, :float
    field :credit, :float
    field :debt, :float
  end

  object :analysis_balance_series do
    field :x, :string
    field :y, :float
  end

  object :analysis_balance do
    field :balance, list_of(:analysis_balance_series)
    field :outstanding_tokens, list_of(:analysis_balance_series)
    field :outstanding_attendance, list_of(:analysis_balance_series)
  end

  object :analysis_queries do
    field :analysis, :analysis do
      arg(:from, non_null(:string))
      arg(:to, non_null(:string))

      resolve(fn _, %{from: from, to: to}, _ ->
        from = Date.from_iso8601!(from)
        to = Date.from_iso8601!(to)

        transactions_income =
          from(t in Oas.Transactions.Transaction,
            where:
              t.when >= ^from and t.when <= ^to and t.type == "INCOMING" and
                (t.not_transaction == false or is_nil(t.not_transaction)),
            select: sum(t.amount)
          )
          |> Oas.Repo.one!() || Decimal.new(0)

        transactions_outgoing =
          from(t in Oas.Transactions.Transaction,
            where:
              t.when >= ^from and t.when <= ^to and t.type == "OUTGOING" and
                (t.not_transaction == false or is_nil(t.not_transaction)),
            select: sum(t.amount)
          )
          |> Oas.Repo.one!() || Decimal.new(0)

        transactions_difference =
          from(t in Oas.Transactions.Transaction,
            where:
              t.when >= ^from and t.when <= ^to and
                (t.not_transaction == false or is_nil(t.not_transaction)),
            select: sum(t.amount)
          )
          |> Oas.Repo.one!() || Decimal.new(0)

        unused_tokens =
          from(t in Oas.Tokens.Token,
            select: count(t.id),
            where: t.expires_on > ^to and is_nil(t.used_on)
          )
          |> Oas.Repo.one!()

        unused_tokens_amount =
          from(t in Oas.Tokens.Token,
            where: t.expires_on > ^to and is_nil(t.used_on),
            select: sum(t.value)
          )
          |> Oas.Repo.one()

        transactions_ballance =
          from(t in Oas.Transactions.Transaction,
            select: sum(t.amount)
          )
          |> Oas.Repo.one!() || Decimal.new(0)

        {:ok,
         %{
           transactions_income: transactions_income |> Decimal.to_float(),
           transactions_outgoing: transactions_outgoing |> Decimal.to_float(),
           transactions_difference: transactions_difference |> Decimal.to_float(),
           unused_tokens: unused_tokens,
           unused_tokens_amount: (unused_tokens_amount || Decimal.new(0)) |> Decimal.to_float(),
           transactions_ballance: transactions_ballance |> Decimal.to_float(),
           credit: Oas.Credits.Credit.get_global_credits(),
           debt: Oas.Credits.Credit.get_global_debt()
         }}
      end)
    end

    field :analysis_balance, type: :analysis_balance do
      arg(:from, non_null(:string))
      arg(:to, non_null(:string))

      resolve(fn _, %{from: from, to: to}, _ ->
        from = Date.from_iso8601!(from)
        to = Date.from_iso8601!(to)

        case abs(Date.diff(from, to)) do
          x when x > 1825 ->
            {:error, "Date difference is too large, max difference is 5 years"}

          _ ->
            {:ok,
             %{
               balance: Oas.Analysis.series_balance(from, to),
               outstanding_tokens: Oas.Analysis.outstanding_tokens(from, to),
               outstanding_attendance: Oas.Analysis.outstanding_attendance(from, to)
             }}
        end
      end)
    end
  end
end
