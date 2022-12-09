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
end