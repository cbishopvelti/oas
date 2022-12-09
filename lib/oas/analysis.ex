import Ecto.Query, only: [from: 2]

defmodule Oas.Analysis do
  def series_balance(from, to) do
    startBalance = from(t in Oas.Transactions.Transaction, 
      where: t.when <= ^from,
      select: sum(t.amount)
    ) |> Oas.Repo.one
    |> case do
      nil -> Decimal.new(0)
      x -> x
    end

    balances = from(t in Oas.Transactions.Transaction,
      where: t.when > ^ from and t.when <= ^to,
      group_by: t.when,
      select: {sum(t.amount), t.when},
      order_by: [asc: t.when]
    ) |> Oas.Repo.all
    |> Enum.map_reduce(startBalance, fn {amount, when1}, acc ->
      accBalance = Decimal.add(acc, amount)
      {{accBalance, when1}, accBalance}
    end)
    |> case do
      {balances, total} -> balances ++ [{total, to}]
    end
    |> Enum.map(fn {balance, when1} -> %{x: when1, y: balance |> Decimal.to_float} end)


    [%{x: from, y: startBalance |> Decimal.to_float} | balances]
  end


  
  def outstanding_tokens(from, to) do

    fromDT = Timex.to_naive_datetime(Date.add(from, 1))
      |> DateTime.from_naive!("Etc/UTC")
    toDT = Timex.to_naive_datetime(Date.add(to, 1))
      |> DateTime.from_naive!("Etc/UTC")

    # IO.puts("001")
    # IO.inspect(fromDT)

    # startOutstandingTokensQuery = from(t in Oas.Tokens.Token,
    #   left_join: tr in assoc(t, :transaction),
    #   where: t.expires_on > ^from and (t.used_on > ^from or is_nil(t.used_on))
    #     and ((not(is_nil(tr.id)) and tr.when <= ^from )
    #     or (is_nil(tr.id) and t.inserted_at < ^fromDT)),
    #   select: sum(t.value)
    # )
    # startOutstandingTokens = startOutstandingTokensQuery |> Oas.Repo.one
    # IO.inspect(Oas.Repo.to_sql(:all, startOutstandingTokensQuery))

    tokens = from(t in Oas.Tokens.Token,
      left_join: tr in assoc(t, :transaction),
      preload: [transaction: tr],
      where: ((not(is_nil(tr.id)) and tr.when <= ^to )
        or (is_nil(tr.id) and t.inserted_at < ^toDT))
      and t.expires_on > ^from and (t.used_on > ^from or is_nil(t.used_on)),
      select: t,
      order_by: [desc: t.id]
    ) |> Oas.Repo.all

    frequency = tokens
    # |> Enum.take(1) # DEBUG ONLY
    |> Enum.reduce(%{}, fn (token, acc) ->
      startDate = case token do
        %{transaction: %{when: when1}} ->
          when1
        %{inserted_at: inserted_at} ->
          inserted_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_date()
      end
      |> (&(case Date.compare(&1, from) do
        :gt -> &1
        :eq -> &1
        _ ->
          from
      end)).()

      # IO.puts("101.1 startDate")
      # IO.inspect(startDate)

      endDate = 
      (token.used_on || token.expires_on)
      |> (&(case Date.compare((token.used_on || token.expires_on), to) do
        :lt -> &1
        :eq -> &1
        _ -> to
      end)).()

      # IO.puts("101.2 endDate")
      # IO.inspect(endDate)
      
      Date.range(startDate, endDate)
        |> Enum.reduce(acc, fn (day, acc) -> 
          Map.put(acc, day, Decimal.add(Map.get(acc, day, Decimal.new(0)), token.value))
        end)
    end)


    out = Date.range(from, to)
    |> Enum.map(fn day ->
      %{
        y: Map.get(frequency, day, 0) |> Decimal.to_float,
        x: day
      }
    end)


    # def tokens = from(t in Oas.Tokens.Token,
    #   where: (!is_nil(t.transaction) and t.transaction.when <= ^from )
    #   or (is_nil(t.transaction) and t.inserted_at <= ^from)
    # )

    IO.puts("002")
    IO.inspect(out)

    out
  end
end