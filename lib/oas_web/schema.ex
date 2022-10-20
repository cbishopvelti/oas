# filename: myapp/schema.ex
import Ecto.Query, only: [from: 2]


defmodule OasWeb.Schema do
  use Absinthe.Schema

  object :item do
    field :id, :id
    field :name, :string
  end

  object :member do
    field :id, :integer
    field :name, :string
    field :email, :string
    field :tokens, :integer
  end

  object :memberWithPassword do
    field :id, :id
    field :name, :string
    field :email, :string
    field :password, :string
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
  end

  object :token do
    field :id, :id
    field :expires_on, :string
    field :used_on, :string
    field :member_id, :integer
    field :member, :member do
      resolve fn parent, _, _ ->
        member = Oas.Repo.one!(Ecto.assoc(parent, :member))
        {:ok, member}
      end
    end
  end

  object :training do
    field :id, :integer
    field :where, :string
    field :when, :string
    field :attendance, :integer
  end

  object :add_attendance do
    field :id, :integer
    field :training_id, :integer
    field :member_id, :integer
  end

  object :add_tokens do
    field :amount, :integer
  end

  object :success do
    field :success, :boolean
  end

  defp handle_error(result) do
    case result do
      {:error, %{errors: errors}} -> 
        outError = errors |> Enum.map(fn {key, {value, _}} -> Atom.to_string(key) <> ": " <> value end)
        {:error, outError}
      x -> x
    end
  end

  # input_object :member_

  query do
    field :attendance, list_of(:member) do 
      arg :training_id, non_null(:integer)
      resolve fn _, %{training_id: training_id}, _ ->
        results = from(m in Oas.Members.Member,
          select: m,
          inner_join: a in assoc(m, :attendance),
          where: a.training_id == ^training_id
        ) |> Oas.Repo.all
        |> Enum.map(fn record ->
          %{id: id} = record
          tokens = Oas.Attendance.get_token_amount(%{member_id: id})
          Map.put(record, :tokens, tokens)
        end)

        {:ok, results}
      end
    end
    field :members, list_of(:member) do
      resolve fn _, %{context: context} ->
        query = from m in Oas.Members.Member, select: m
        result = Oas.Repo.all(query)

        result = result
        |> Enum.map(fn record ->
          %{id: id} = record
          tokens = Oas.Attendance.get_token_amount(%{member_id: id})
          Map.put(record, :tokens, tokens)
        end)


        {:ok, result}
      end
    end
    field :member, :member do
      arg :member_id, non_null(:integer)
      resolve fn _, %{member_id: member_id}, _ ->
        query = from(m in Oas.Members.Member, where: m.id == ^member_id)
        result = Oas.Repo.one(query)

        tokens = Oas.Attendance.get_token_amount(%{member_id: member_id})

        {:ok, Map.put(result, :tokens, tokens)}
      end
    end
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
    field :tokens, list_of(:token) do
      arg :member_id, :integer
      arg :transaction_id, :integer
      resolve fn
        _, %{member_id: _, transaction_id: _}, _ ->
          {:error, "member_id and transaction_id can not both be set"}
        _, %{transaction_id: transaction_id}, _ ->
          query = from(t in Oas.Tokens.Token, select: t, where: t.transaction_id == ^transaction_id, order_by: [desc: t.expires_on, desc: t.id])
          result = Oas.Repo.all(query)
          {:ok, result}
        _, %{member_id: member_id}, _ ->
          query = from(t in Oas.Tokens.Token, select: t, where: t.member_id == ^member_id, order_by: [desc: t.expires_on, desc: t.id])
          result = Oas.Repo.all(query)
          {:ok, result}
      end
    end

    field :training, :training do
      arg :id, non_null(:integer)
      resolve fn _, %{id: id}, _ ->
        query = from(t in Oas.Trainings.Training, select: t, where: t.id == ^id)
        result = Oas.Repo.one(query)
        {:ok, result}
      end
    end
    field :trainings, list_of(:training) do
      resolve fn _, _, _ ->

        # query = from(t in Oas.Trainings.Training, as: :training,
        #   join: c in subquery(
        #     from a in Oas.Trainings.Attendance,
        #     select: %{uid: a.id, count: count(a.id)},
        #     where: [training_id: parent_as(:training).id],
        #     group_by: a.id
        #   ),
        #   select: {t, c}
        # )

        results = from(t in Oas.Trainings.Training,
          left_join: a in assoc(t, :attendance),
          group_by: [t.id],
          select: %{training: t, attendance: count(a.id)},
          order_by: [desc: t.when, desc: t.id]
        ) |> Oas.Repo.all
        |> Enum.map(fn %{training: t, attendance: a} -> %{t | attendance: a} end)

        {:ok, results}
      end
    end
  end

  # object :transaction do
  #   field :id, :id
  # end

  mutation do 
    @desc "Create or update member"
    field :new_member, type: :memberWithPassword do
      arg :id, :integer
      arg :name, non_null(:string)
      arg :email, non_null(:string)
      resolve fn _parent, args, context ->
        # %{id: id} = args

        result = case Map.get(args, :id, nil) do
          nil -> length = 12
            password = :crypto.strong_rand_bytes(length) |> Base.encode64 |> binary_part(0, length)
            case Oas.Members.register_member(Map.merge(%{password: password}, args)) do
              {:ok, result} -> {:ok, Map.merge(result, %{password: password})}
              errored -> handle_error(errored)
            end
          id -> 
            result = Oas.Repo.get!(Oas.Members.Member, id)
              |> Ecto.Changeset.cast(args, [:email, :name])
              |> Ecto.Changeset.validate_required([:name, :email])
              |> Oas.Members.Member.validate_email
              |> Oas.Repo.update
              |> handle_error
            result
        end
      end
    end
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
      resolve fn _parent, args, context ->
        when1 = Date.from_iso8601!(args.when)
        args = %{args | when: when1}

        toSave = case Map.get(args, :id) do
          nil -> %Oas.Transactions.Transaction{}
          id -> Oas.Repo.get!(Oas.Transactions.Transaction, id)
        end
        # toSave = Map.merge(%Oas.Transactions.Transaction{}, args)

        changeset = toSave
          |> Ecto.Changeset.cast(args, [:what, :when, :who, :who_member_id, :type, :amount, :bank_details, :notes])
        result = 
          changeset
          |> (&(case &1 do
            %{data: %{id: nil}} -> Oas.Repo.insert!(&1)
            %{data: %{id: _}} -> 
              Oas.Repo.update!(&1)
          end)).()
          |> handle_error

        if (Map.has_key?(args, :token_quantity) and !Map.has_key?(args, :id)) do
          Oas.Attendance.add_tokens(%{
            member_id: args.who_member_id,
            transaction_id: result.id,
            quantity: args.token_quantity,
            when1: when1
          })
        end


        {:ok, %{id: result.id}}
      end
    end
    field :add_tokens, type: :add_tokens do
      arg :transaction_id, :integer
      arg :member_id, :integer
      arg :amount, :integer
      resolve fn _, %{amount: amount, transaction_id: transaction_id, member_id: member_id}, _ -> 
        result = Oas.Attendance.add_tokens(%{
          member_id: member_id,
          transaction_id: transaction_id,
          quantity: amount,
          when1: Oas.Repo.get!(Oas.Transactions.Transaction, transaction_id).when
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
    @desc "Insert training"
    field :insert_training, type: :training do
      arg :where, non_null(:string)
      arg :when, non_null(:string)
      resolve fn _, args, _ ->
        when1 = Date.from_iso8601!(args.when)
        args = %{args | when: when1}
        {:ok, result} = Map.merge(%Oas.Trainings.Training{}, args)
          |> Oas.Repo.insert

        {:ok, result}
      end
    end
    @desc "update training"
    field :update_training, type: :training do
      arg :id, non_null(:integer)
      arg :where, non_null(:string)
      arg :when, non_null(:string)
      resolve fn _, args, _ ->
        when1 = Date.from_iso8601!(args.when)
        args = %{args | when: when1}
        training = Oas.Repo.get!(Oas.Trainings.Training, args.id)

        toSave = Ecto.Changeset.change training, args

        {:ok, result} = toSave
          |> Oas.Repo.update

        {:ok, result}
      end
    end
    @desc "Add attendance"
    field :add_attendance, type: :add_attendance do
      arg :member_id, non_null(:integer)
      arg :training_id, non_null(:integer)
      resolve fn _, args, _ ->
        Oas.Attendance.add_attendance(args)
      end
    end
  end
  

end