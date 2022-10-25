import Ecto.Query, only: [from: 2, where: 3]
defmodule OasWeb.Schema.SchemaTransaction do
  use Absinthe.Schema.Notation
  
  object :transaction do
    field :id, :integer
    field :what, :string
    field :who, :string
    field :who_member_id, :integer
    field :type, :string
    field :bank_details, :string
    field :notes, :string
    field :when, :string
    field :amount, :string
    field :tokens, list_of(:token)
  end

  object :transaction_queries do
    field :transactions, list_of(:transaction) do
      resolve fn _, %{context: context} ->
        query = from(t in Oas.Transactions.Transaction, select: t, order_by: [desc: t.when, desc: t.id])
        result = Oas.Repo.all(query)
        {:ok, result}
      end
    end
    field :transaction, :transaction do
      arg :id, :integer
      resolve fn _, %{id: id}, _ ->
        transaction = Oas.Repo.get!(Oas.Transactions.Transaction, id)
        {:ok, transaction}
      end
    end
  end

  object :transaction_mutations do
    @desc "Create transaction"
    field :transaction, type: :transaction do
      arg :id, :integer
      arg :what, non_null(:string)
      arg :when, non_null(:string)
      arg :who, :string
      arg :who_member_id, :integer
      arg :type, non_null(:string)
      arg :amount, non_null(:float)
      arg :bank_details, :string
      arg :notes, :string
      arg :token_quantity, :integer
      arg :token_value, :float
      resolve fn _parent, args, context ->
        when1 = Date.from_iso8601!(args.when)
        args = %{args | when: when1}

        toSave = case Map.get(args, :id) do
          nil -> %Oas.Transactions.Transaction{}
          id -> Oas.Repo.get!(Oas.Transactions.Transaction, id)
        end

        result = toSave
          |> Oas.Transactions.Transaction.changeset(args)
          |> (&(case &1 do
            %{data: %{id: nil}} -> Oas.Repo.insert(&1)
            %{data: %{id: _}} -> Oas.Repo.update(&1)
          end)).()
          |> OasWeb.Schema.SchemaUtils.handle_error

      
        case result do
          {:error, error} -> {:error, error}
          {:ok, result} ->
            if (Map.has_key?(args, :token_quantity) and !Map.has_key?(args, :id)) do
              Oas.Attendance.add_tokens(%{
                member_id: args.who_member_id,
                transaction_id: result.id,
                quantity: args.token_quantity,
                value: args.token_value,
                when1: when1
              })
            end

            {:ok, result}
        end
      end
    end
  end


end