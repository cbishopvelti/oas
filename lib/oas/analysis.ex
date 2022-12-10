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
      # left_join: att in assoc(t, :attendance),
      # left_join: tra in assoc(att, :training),
      # preload: [transaction: tr, attendance: {att, [training: tra]}],
      preload: [transaction: tr],
      where: ((not(is_nil(tr.id)) and tr.when <= ^to )
        or (is_nil(tr.id) and t.inserted_at < ^toDT))
      and t.expires_on > ^from and (t.used_on > ^from or is_nil(t.used_on)),
      select: t,
      order_by: [desc: t.id]
    ) |> Oas.Repo.all

    frequency = tokens
    # |> Enum.take(1) # DEBUG ONLY
    # |> Enum.filter(fn (token) -> token.id == 2 end) # DEBUG ONLY
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

      endDate = 
      (token.used_on || token.expires_on)
      |> (&(case Date.compare(&1, to) do
        :lt -> &1
        :eq -> &1
        _ -> to
      end)).()
      
      Date.range(startDate, endDate)
        |> Enum.reduce(acc, fn (day, acc) -> 
          Map.put(acc, day, Decimal.add(Map.get(acc, day, Decimal.new(0)), token.value))
        end)
    end)


    out = Date.range(from, to)
    |> Enum.map(fn day ->
      %{
        y: Map.get(frequency, day, Decimal.new(0)) |> Decimal.to_float,
        x: day
      }
    end)

    # IO.puts("002")
    # IO.inspect(out)

    out
  end
  def outstanding_attendance(from, to) do
    # Attendances which dont have a token
    attendance = from(att in Oas.Trainings.Attendance,
      left_join: tok in assoc(att, :token),
      inner_join: tra in assoc(att, :training),
      preload: [token: tok, training: tra],
      where: tra.when <= ^to and
        (is_nil(tok.used_on) or tok.used_on >= ^from)
    ) |> Oas.Repo.all

    minValue = from(cto in Oas.Config.Tokens,
      select: min(cto.value)
    ) |> Oas.Repo.one

    frequency = attendance
    |> Enum.reduce(%{}, fn (attendance, acc) ->
      startDate = attendance.training.when
      
      endDate = case (attendance.token && attendance.token.used_on) do
        nil -> to
        x -> x
      end

      value = case attendance.token do
        %{value: value} -> value
        value -> minValue
      end

      Date.range(startDate, endDate)
        |> Enum.reduce(acc, fn (day, acc) ->
          Map.put(acc, day, Decimal.sub(Map.get(acc, day, Decimal.new(0)), value ))
        end)
    end)

    # IO.puts("003")
    # IO.inspect(attendance)

    out = Date.range(from, to)
    |> Enum.map(fn day -> 
      %{
        y: Map.get(frequency, day, Decimal.new(0)) |> Decimal.to_float,
        x: day
      }
    end)
  end
end