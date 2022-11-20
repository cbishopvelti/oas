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
    field :transaction, :transaction
    field :attendance, :member_attendance_attendance
  end

  object :public_member do
    field :name, :string
    field :email, :string
  end

  object :public_token do
    field :id, :integer
    field :expires_on, :string
    field :used_on, :string
    field :value, :string
    field :tr_member, :public_member
    field :member, :public_member
  end

  object :add_tokens do
    field :amount, :integer
  end

  object :public_attendance do
    field :id, :integer
    field :training_where, :training_where
    field :when, :string
  end

  object :token_queries do
    field :tokens, list_of(:token) do
      arg :member_id, :integer
      arg :transaction_id, :integer
      resolve fn
        _, %{member_id: _, transaction_id: _}, _ ->
          {:error, "member_id and transaction_id can not both be set"}
        _, %{transaction_id: transaction_id}, _ ->
          query = from(
            t in Oas.Tokens.Token,
            select: t,
            where: t.transaction_id == ^transaction_id,
            order_by: [desc: t.expires_on, desc: t.id],
            preload: [:transaction, attendance: [:training]]
          )
          result = Oas.Repo.all(query)
          {:ok, result |> Enum.map(fn r -> Map.put(r, :value, Decimal.to_float(r.value)) end)}
        _, %{member_id: member_id}, _ ->
          query = from(
            t in Oas.Tokens.Token,
            select: t,
            where: t.member_id == ^member_id,
            order_by: [desc: t.expires_on, desc: t.id],
            preload: [:transaction, attendance: [:training]]
          )
          result = Oas.Repo.all(query)
          {:ok, result |> Enum.map(fn r -> Map.put(r, :value, Decimal.to_float(r.value)) end)}
      end
    end

    field :public_tokens, type: list_of(:public_token) do
      arg :email, non_null(:string)
      resolve fn _, %{email: email}, _ ->

        member = from(
          m in Oas.Members.Member,
          where: m.email == ^email
        ) |> Oas.Repo.one
        case member do
          nil ->
            {:error, "Member not found"}
          _ -> 
            tokens = from(to in Oas.Tokens.Token,
              left_join: m in assoc(to, :member),
              left_join: tr in assoc(to, :transaction),
              left_join: mftr in assoc(tr, :member),
              where: m.email == ^email or mftr.email == ^email,
              select: {to, m, mftr},
              order_by: [desc: to.expires_on, desc: to.id]
            ) |> Oas.Repo.all
            |> Enum.map(fn ({to, m, m_tr}) ->
              Map.put(to, :member, m)
              |> Map.put(:tr_member, m_tr)
            end)


            {:ok, tokens}
        end
      end
    end

    field :public_outstanding_attendance, type: list_of(:public_attendance) do
      arg :email, non_null(:string)
      resolve fn _, %{email: email}, _ -> 
        trainings = from(
          tr in Oas.Trainings.Training,
          preload: :training_where,
          inner_join: at in assoc(tr, :attendance),
          inner_join: m in assoc(at, :member),
          left_join: to in assoc(at, :token),
          where: is_nil(to.id) and m.email == ^email,
          order_by: [desc: tr.when]
        ) |> Oas.Repo.all

        {:ok, trainings}
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