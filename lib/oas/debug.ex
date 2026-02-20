import Ecto.Query, only: [from: 2]

defmodule Oas.Debug do


  # Oas.Debug.force_delete_transaction(556)
  def force_delete_transaction(transaction_id) do
    tokens = from(t in Oas.Tokens.Token,
      where: t.transaction_id == ^transaction_id
    ) # |> Oas.Repo.all()
    |> Oas.Repo.delete_all()

    credits = from(c in Oas.Credits.Credit,
      where: c.transaction_id == ^transaction_id
    ) # |> Oas.Repo.all()
    |> Oas.Repo.delete_all()

    # Oas.Repo.get!(Oas.Transactions.Gocardless, transaction_id)
    result2 = from(g in Oas.Transactions.Gocardless, where: g.transaction_id == ^transaction_id) |> Oas.Repo.delete_all()
    # |> Oas.Repo.all()
    IO.inspect(result2, label: "004")

    result = Oas.Repo.get!(Oas.Transactions.Transaction, transaction_id) |> Oas.Repo.delete()

    IO.inspect(result, label: "003")



  end
end
