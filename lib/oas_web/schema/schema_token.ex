import Ecto.Query, only: [from: 2, where: 3]
defmodule OasWeb.Schema.SchemaToken do
  use Absinthe.Schema.Notation

  object :token do
    field :id, :id
    field :expires_on, :string
    field :used_on, :string
    field :member_id, :integer
    field :value, :float
    field :member, :member do
      resolve fn parent, _, _ ->
        member = Oas.Repo.one!(Ecto.assoc(parent, :member))
        {:ok, member}
      end
    end
  end

  object :add_tokens do
    field :amount, :integer
  end

  object :token_queries do
    field :tokens, list_of(:token) do
      arg :member_id, :integer
      arg :transaction_id, :integer
      resolve fn
        _, %{member_id: _, transaction_id: _}, _ ->
          {:error, "member_id and transaction_id can not both be set"}
        _, %{transaction_id: transaction_id}, _ ->
          query = from(t in Oas.Tokens.Token, select: t, where: t.transaction_id == ^transaction_id, order_by: [desc: t.expires_on, desc: t.id])
          result = Oas.Repo.all(query)
          {:ok, result |> Enum.map(fn r -> Map.put(r, :value, Decimal.to_float(r.value)) end)}
        _, %{member_id: member_id}, _ ->
          query = from(t in Oas.Tokens.Token, select: t, where: t.member_id == ^member_id, order_by: [desc: t.expires_on, desc: t.id])
          result = Oas.Repo.all(query)
          {:ok, result |> Enum.map(fn r -> Map.put(r, :value, Decimal.to_float(r.value)) end)}
      end
    end
  end

  object :token_mutations do
    field :add_tokens, type: :add_tokens do
      arg :transaction_id, :integer
      arg :member_id, :integer
      arg :amount, :integer
      arg :value, :float
      resolve fn _, %{amount: amount, transaction_id: transaction_id, member_id: member_id, value: value}, _ -> 
        result = Oas.Attendance.add_tokens(%{
          member_id: member_id,
          transaction_id: transaction_id,
          quantity: amount,
          when1: Oas.Repo.get!(Oas.Transactions.Transaction, transaction_id).when,
          value: value
        })
        {:ok, %{amount: amount}}
      end
    end
    field :delete_tokens, type: :success do
      arg :token_id, non_null(:integer)
      resolve fn _, %{token_id: token_id}, _ ->
        token = Oas.Repo.get!(Oas.Tokens.Token, token_id)
        # The relationship should probably have been the other way around
        if (token.attendance_id != nil) do
          {:error, "Token has been used"}
        else
          result = Oas.Repo.delete(token)
          {:ok, %{success: true}}
        end
      end
    end
    field :transfer_token, type: :token do
      arg :token_id, non_null(:integer)
      arg :member_id, non_null(:integer)
      resolve fn _, %{token_id: token_id, member_id: member_id}, _ ->
        token = Oas.Repo.get!(Oas.Tokens.Token, token_id)
        if (token.attendance_id != nil) do
          {:error, "Token has been used"}
        else
          token = Oas.Attendance.transfer_token(%{token: token, member_id: member_id})
          
          {:ok, token}
        end        
      end
    end
  end

end