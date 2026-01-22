import Ecto.Query, only: [from: 2]

defmodule OasWeb.Schema.SchemaAnalysisAnnual do
  use Absinthe.Schema.Notation
  require Logger

  object :tagged do
    field :tag_names, list_of(:string)
    field :amount, :float
  end

  object :annual_income do
    field :total, :float
    field :tagged, list_of(:tagged)
  end

  object :annual_receivables do
    field :tokens, :float
    field :credits, :float
    field :total, :float
  end
  object :annual_liabilities do
    field :credits, :float
    field :total, :float
  end

  object :annual do
    field :annual_balance, :float do
      resolve fn parent, _, _ ->
        IO.puts("005 ------------")
        to = parent.to |> Date.from_iso8601!()
        out = from(t in Oas.Transactions.Transaction,
          where: t.when <= ^to,
          select: sum(t.amount)
        )
        |> (&(Oas.Repo.one(&1) || Decimal.new(0))).()
        |> Decimal.to_float()

        {:ok, out}
      end
    end
    field :annual_liabilities, :annual_liabilities do
      resolve fn parent, _, _ ->
        credits = Oas.Credits.Credit.get_global_credits_to(Date.from_iso8601!(parent.to))

        {:ok, %{
          credits: credits,
          total: credits
        }}
      end
    end
    field :annual_expenses, :annual_income do
      resolve fn parent, _, _ ->
        {total, tagged} = from(t in Oas.Transactions.Transaction,
          preload: [:transaction_tags],
          where: t.when >= ^parent.from and t.when <= ^parent.to and t.amount < ^0
        )
        |> Oas.Repo.all()
        |> Enum.reduce({Decimal.new("0"), %{}}, fn (
          %{amount: amount, transaction_tags: transaction_tags},
          {total, tagged}
        ) ->
          amount = Decimal.abs(amount)
          my_tags = transaction_tags |> Enum.map(fn %{name: name} -> name end) |> MapSet.new()
          inter_tags = MapSet.intersection(my_tags, parent.transaction_tags)
          {Decimal.add(total, amount),
            tagged |> Map.put(
              inter_tags,
              Map.get(tagged, inter_tags, Decimal.new("0")) |> Decimal.add(amount)
            )
          }
        end)

        {:ok, %{
          tagged: tagged |> Map.to_list()
          |> Enum.map(fn {k, v} ->
            %{
              tag_names: MapSet.to_list(k),
              amount: Decimal.to_float(v) |> Float.round(2)
            }
          end),
          total: total |> Decimal.to_float()
            |> Float.round(2)
        }}
      end
    end
    field :annual_receivables, :annual_receivables do
      resolve fn parent, _, _ ->
        tokens = from(att in Oas.Trainings.Attendance,
          left_join: tok in assoc(att, :token),
          inner_join: tra in assoc(att, :training),
          left_join: cre in assoc(att, :credit),
          # inner_join: mem in assoc(tok, :member), # DEBUG ONLY
          where: tra.when <= ^parent.to and
            (is_nil(tok.used_on))
            and is_nil(cre.id),
          select: count(att.id)
        ) |> Oas.Repo.one!()
        |> Decimal.mult(Oas.Config.Tokens.get_min_token().value)

        credits = Oas.Credits.Credit.get_global_debt_to(parent.to) |> abs()

        total = Decimal.add(tokens, Decimal.from_float(credits))

        {:ok, %{
          tokens: tokens |> Decimal.to_float(),
          credits: credits,
          total: total |> Decimal.to_float()
        }}
      end
    end
    field :annual_income, :annual_income do
      resolve fn parent, _b, _c ->

        total = from(t in Oas.Transactions.Transaction,
          where: t.when >= ^parent.from and t.when <= ^parent.to and t.amount >= ^0
        )
        |> Oas.Repo.all()
        |> Enum.reduce(Decimal.new("0"), fn (%{amount: amount}, acc) ->
          Decimal.add(acc, amount)
        end)
        |> Decimal.to_float()
        |> Float.round(2)

        # Tokens & Credits
        # from(to in Oas.Tokens.Token,
        #   inner_join: tr in assoc(to, :transaction),
        #   where: tr.when >= ^parent.from and tr.when <= ^parent.to and tr.amount >= ^0
        # )
        tagged = from(tr in Oas.Transactions.Transaction,
          left_join: to in assoc(tr, :tokens),
          left_join: cr in assoc(tr, :credit),
          preload: [:transaction_tags, tokens: to, credit: cr,],
          where: tr.when >= ^parent.from and tr.when <= ^parent.to and tr.amount >= ^0,
          order_by: [desc: tr.id]
          # limit: 2
        )
        |> Oas.Repo.all()
        |> Enum.reduce(%{}, fn (tr, acc) -> # EACH ROW
          my_tags = tr.transaction_tags |> Enum.map(fn %{name: name} -> name end) |> MapSet.new()
          inter_tags = MapSet.intersection(my_tags, parent.transaction_tags)
          case {tr.credit, tr.tokens} do
            {nil, [_x | _to]} ->
              if (parent.transaction_tags |> MapSet.member?("Tokens")) do
                key = inter_tags |> MapSet.put("Tokens")
                acc |> Map.put(
                  key,
                  Map.get(acc, key, Decimal.new("0")) |> Decimal.add(tr.amount)
                )
              else
                acc |> Map.put(
                  MapSet.new(),
                  Map.get(acc, MapSet.new(), Decimal.new("0")) |> Decimal.add(tr.amount)
                )
              end
            {cr, []} when not is_nil(cr)->
              if (parent.transaction_tags |> MapSet.member?("Credits")) do
                key = inter_tags |> MapSet.put("Credits")
                # IO.puts("002 key #{inspect(key)}")
                acc |> Map.put(
                  key,
                  Map.get(acc, key, Decimal.new("0")) |> Decimal.add(tr.amount)
                )
              else
                acc |> Map.put(
                  MapSet.new(),
                  Map.get(acc, MapSet.new(), Decimal.new("0")) |> Decimal.add(tr.amount)
                )
              end
            {cr, [_x | _rest]} when not is_nil(cr) ->
              out = {
                (tr.credit || %{amount: Decimal.new("0")}).amount,
                tr.tokens |> Enum.reduce(Decimal.new("0"), fn (t, acc) -> Decimal.add(t.value, acc) end)
              }
              if not (Decimal.add(out |> elem(0), out |> elem(1)) |> Decimal.eq?(tr.amount)) do
                raise "Invalid credit + tokens amount"
              end
              if (parent.transaction_tags |> MapSet.member?("Credits")) do
                key = inter_tags |> MapSet.delete("Tokens") |> MapSet.put("Credits")
                # IO.puts("003 key #{inspect(key)}")
                acc |> Map.put(
                  key,
                  Map.get(acc, key, Decimal.new("0")) |> Decimal.add(elem(out, 0))
                )
              else
                acc |> Map.put(
                  MapSet.new(),
                  Map.get(acc, MapSet.new(), Decimal.new("0")) |> Decimal.add(elem(out, 0))
                )
              end
              |> then(fn acc ->
                if (parent.transaction_tags |> MapSet.member?("Tokens")) do
                  key = inter_tags |> MapSet.delete("Credits") |> MapSet.put("Tokens")
                  # IO.puts("004 key #{inspect(key)}")
                  acc |> Map.put(
                    key,
                    Map.get(acc, key, Decimal.new("0")) |> Decimal.add(elem(out, 1))
                  )
                else
                  acc |> Map.put(
                    MapSet.new(),
                    Map.get(acc, MapSet.new(), Decimal.new("0")) |> Decimal.add(elem(out, 1))
                  )
                end
              end)
            {nil, []} -> # Not a credit or token
              acc |> Map.put(
                inter_tags,
                Map.get(acc, inter_tags, Decimal.new("0")) |> Decimal.add(tr.amount)
              )
          end

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
          # credit: Decimal.to_float(credit) |> Float.round(2),
          # tokens: Decimal.to_float(tokens) |> Float.round(2),
          tagged: tagged
            |> Map.to_list()
            |> Enum.map(fn {k, v} ->
              %{
                tag_names: MapSet.to_list(k),
                amount: Decimal.to_float(v) |> Float.round(2)
              }
            end),
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
      resolve fn _, %{from: from, to: to} = args, _ ->
        transaction_tags = Map.get(args, :transaction_tags, [])
        # IO.inspect(transaction_tags, label: "001")
        {:ok, %{
          from: from,
          to: to,
          transaction_tags: MapSet.new(transaction_tags |> Enum.map(fn %{name: name} -> name end))
        }}
      end
    end
  end
end
