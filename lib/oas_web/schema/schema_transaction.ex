import Ecto.Query, only: [from: 2, where: 3]
defmodule OasWeb.Schema.SchemaTransaction do
  use Absinthe.Schema.Notation
  
  input_object :transaction_tag_arg do
    field :id, :integer
    field :name, non_null(:string)
  end

  object :transaction_tag do
    field :id, :integer
    field :name, :string
  end

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
    field :transaction_tags, list_of(:transaction_tag)
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
        transaction = Oas.Repo.get!(Oas.Transactions.Transaction, id) |> Oas.Repo.preload(:transaction_tags)
        {:ok, transaction}
      end
    end
    field :transaction_tags, list_of(:transaction_tag) do
      resolve fn _, _, _ ->
        result = Oas.Repo.all(from(t in Oas.Transactions.TransactionTags, select: t))
        {:ok, result}
      end
    end
  end

  object :transaction_mutations do
    @desc "Create or Update transaction"
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
      arg :transaction_tags, list_of(:transaction_tag_arg)
      resolve fn _parent, args, context ->
        when1 = Date.from_iso8601!(args.when)
        args = %{args | when: when1}

        doTransactionTags = fn (changeset) -> 
          IO.puts("001")
          case args do
            %{transaction_tags: transaction_tags} -> 
              IO.puts("002")
              transaction_tags = transaction_tags
                |> Enum.map(fn
                  %{id: id} -> Oas.Repo.get!(Oas.Transactions.TransactionTags, id)
                  rest -> rest
                end)
              IO.inspect(transaction_tags)
              out = Ecto.Changeset.put_assoc(changeset, :transaction_tags, transaction_tags)
              out
            _ -> changeset
          end
        end

        toSave = case Map.get(args, :id) do
          nil -> %Oas.Transactions.Transaction{}
          id -> Oas.Repo.get!(Oas.Transactions.Transaction, id) |> Oas.Repo.preload(:transaction_tags)
        end
          |> Oas.Transactions.Transaction.changeset(args)
          |> doTransactionTags.()

        result = toSave
          |> (&(case &1 do
            %{data: %{id: nil}} -> Oas.Repo.insert(&1)
            %{data: %{id: _}} -> Oas.Repo.update(&1)
          end)).()
          |> OasWeb.Schema.SchemaUtils.handle_error

        # delete unused tags
        removedTransactionTags = Ecto.Changeset.get_change(toSave, :transaction_tags, [])
        |> Enum.filter(fn
          %{action: :replace} -> true
          _ -> false
        end)
        |> Enum.map(fn %{data: %{id: id}} -> id end)

        from(
          tt in Oas.Transactions.TransactionTags,
          as: :transaction_tags,
          where: not(exists(
            from(
              c in "transaction_transaction_tags",
              where: c.transaction_tag_id == parent_as(:transaction_tags).id,
              select: 1
            )
          )) and tt.id in ^removedTransactionTags
        ) |> Oas.Repo.delete_all
        # EO delete unused tags
      
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