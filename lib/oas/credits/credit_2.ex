import Ecto.Query, only: [from: 2]

defmodule Oas.Credits.Credit2 do
  def get_credit_amount(%{member_id: member_id}, opts \\ %{now: Date.utc_today()} ) do
    credits = from(c in Oas.Credits.Credit,
      where: c.who_member_id == ^member_id and c.when <= ^opts.now,
      preload: [:transaction, :debit, :credit, :membership, :attendance],
      # order_by: [asc: coalesce(c.expires_on, c.when), asc_nulls_first: c.expires_on, asc: c.id]
      # order_by: [asc_nulls_last: c.expires_on, asc: c.when, asc: c.id]
      order_by: [asc: c.when, asc: c.id]
    )
    |> Oas.Repo.all()

    {credits, total} = process_credits(credits, opts)
    {
      credits |> Enum.reverse(),
      total,
    }
  end


  defp process_credits(credits, opts) do

    {trans, active_ledger} = credits |> Enum.map_reduce([], fn (credit, ledger) ->
      # IO.puts("vvvvvvvvvvvvvvvv")
      new_ledger = deduct_debit(ledger, credit, opts)
      after_amount = Enum.reduce(new_ledger, Decimal.new("0.0"), fn %{amount: amount}, acc -> Decimal.add(acc, amount) end)
      out = {
        credit |> Map.put(:after_amount, after_amount),
        new_ledger
      }
      # out |> elem(0) |> IO.inspect()
      # IO.puts("^^^^^^^^^^^^^^^^")
      out
    end)

    {
      trans,
      Enum.reduce(
        active_ledger |> Enum.filter(fn
          %{expires_on: nil} -> true
          %{expires_on: expires_on} ->
            Date.compare(expires_on, opts.now) == :gt
        end),
        Decimal.new("0"),
        fn %{amount: amount}, acc -> Decimal.add(acc, amount) end
      )
    }
  end

  # Returns new ledger
  defp deduct_debit(ledger, debit, _opts) # \\ %{now: Date.utc_today()}
  defp deduct_debit([], debit, _opts) do
    [debit]
  end
  # Signs are the same, so can't deduct debt
  defp deduct_debit([%{amount: %Decimal{sign: sign}} = head | tail], %{amount: %Decimal{sign: sign}} = debit, opts ) do
    if ( head.expires_on != nil) do
      [head | deduct_debit(tail, debit, opts)]
      |> Enum.sort_by(fn (%{expires_on: expires_on}) -> expires_on end)
    else
      [head | deduct_debit(tail, debit, opts)]
    end
  end
  defp deduct_debit([head | tail], debit, opts ) do
    # IO.puts("vvvvv")
    out = cond do
      # head has expired
      Map.get(head, :expires_on, nil) != nil and Date.after?(debit.when, head.expires_on) ->
        [debit] ++ [head | tail] # assume rest of the credits are expired as they are ordered
      Decimal.eq?(debit.amount, 0) ->
        [head | tail]
      # Debit amount is greater than the credit in the head, so remove
      Decimal.gte?(Decimal.abs(debit.amount), Decimal.abs(head.amount)) ->
        deduct_debit(tail, %{debit | amount: Decimal.add(debit.amount, head.amount)}, opts)
      # debit amount is less than the credit in the head, so return the head with the amount removed
      Decimal.lt?(Decimal.abs(debit.amount), Decimal.abs(head.amount)) ->
        [%{head | amount: Decimal.add(head.amount, debit.amount)} | tail]
    end
    # IO.puts("^^^^^")
    out
  end
end
