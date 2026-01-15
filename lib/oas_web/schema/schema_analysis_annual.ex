import Ecto.Query, only: [from: 2]

defmodule OasWeb.Schema.SchemaAnalysisAnnual do
  use Absinthe.Schema.Notation
  require Logger

  object :annual_income do
    field :total, :float
    field :tokens, :float
    field :credit, :float
  end

  object :annual do
    field :annual_income, :annual_income do
      resolve fn parent, b, c ->

        total = from(t in Oas.Transactions.Transaction,
          where: t.when >= ^parent.from and t.when <= ^parent.to and t.amount >= ^0
        )
        |> Oas.Repo.all()
        |> Enum.sum_by(fn row ->
          Decimal.to_float(row.amount)
        end)
        |> Float.round(2)

        # Tokens & Credits
        # from(to in Oas.Tokens.Token,
        #   inner_join: tr in assoc(to, :transaction),
        #   where: tr.when >= ^parent.from and tr.when <= ^parent.to and tr.amount >= ^0
        # )
        {credit, tokens} = from(tr in Oas.Transactions.Transaction,
          left_join: to in assoc(tr, :tokens),
          left_join: cr in assoc(tr, :credit),
          preload: [tokens: to, credit: cr],
          where: tr.when >= ^parent.from and tr.when <= ^parent.to and tr.amount >= ^0
        )
        |> Oas.Repo.all()
        |> Enum.map(fn (tr) ->
          case {tr.credit, tr.tokens} do
            {nil, _to} -> {tr, Decimal.new("0"), tr.amount}
            {_cr, []} -> {tr, tr.amount, Decimal.new("0")}
            _ ->
              {
                tr,
                (tr.credit || %{amount: Decimal.new("0")}).amount,
                tr.tokens |> Enum.reduce(Decimal.new("0"), fn (t, acc) -> Decimal.add(t.value, acc) end)
              }
          end
        end)
        |> Enum.filter(fn ({tr, total_credit, total_tokens}) -> # If the tokens or credits where created from nothing, then don't include
          out = Decimal.add(total_credit, total_tokens)
          |> Decimal.gte?(tr.amount)
          if (!out) do
            Logger.info("FILTERED TRANSACTION: #{tr.id}, should not happen")
          end
          out
        end)
        |> Enum.reduce({Decimal.new("0"), Decimal.new("0")}, fn ({_tr, credit, tokens}, {credit_acc, tokens_acc}) ->
          {Decimal.add(credit_acc, credit), Decimal.add(tokens_acc, tokens)}
        end)

        from(tr in Oas.Transactions.Transaction,
          left_join: to in assoc(tr, :tokens),
          left_join: cr in assoc(tr, :credit),
          preload: [tokens: to, credit: cr],
          where: tr.when >= ^parent.from and tr.when <= ^parent.to and tr.amount >= ^0
            and (is_nil(to.id) and is_nil(cr.id))
        )
        |> Oas.Repo.all()
        |> Enum.map(fn tr -> tr.id end)

        {:ok, %{
          total: total,
          credit: Decimal.to_float(credit) |> Float.round(2),
          tokens: Decimal.to_float(tokens) |> Float.round(2),
          from: parent.from,
          to: parent.to
        }}
      end
    end
  end

  object :analysis_annual_queries do
    field :analysis_annual, :annual do
      arg :from, non_null(:string)
      arg :to, non_null(:string)
      arg :transaction_tags, list_of(:transaction_tag_arg)
      resolve fn _, %{from: from, to: to, transaction_tags: transaction_tags}, _ ->
        IO.inspect(transaction_tags, label: "001")
        {:ok, %{
          from: from,
          to: to,
          transaction_tags: transaction_tags
        }}
      end
    end
  end
end
