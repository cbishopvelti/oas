import Ecto.Query, only: [from: 2, where: 3, join: 5, group_by: 3]
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

  object :membership do
    field :id, :integer
    field :transaction_id, :integer
    field :membership_period_id, :integer

    field :transaction, :transaction
    field :member, :member
    field :membership_period, :membership_period
  end

  input_object :credit_arg do
    field :id, :integer
    field :amount, :float
  end

  object :transaction_credit do
    field :amount, :string
    field :expires_on, :string
  end

  object :transaction do
    field :id, :integer
    field :what, :string
    field :who, :string
    field :who_member_id, :integer
    field :training_where_id, :integer
    field :type, :string
    field :bank_details, :string
    field :notes, :string
    field :when, :string
    field :amount, :string
    field :tokens, list_of(:token)
    field :transaction_tags, list_of(:transaction_tag)
    field :membership, :membership
    field :their_reference, :string
    field :my_reference, :string
    field :warnings, :string
    field :credit, :transaction_credit
  end

  object :pending_transaction do
    field :remittance_information_unstructured, :string
    field :booking_date, :string
    field :amount, :string
  end

  object :transaction_queries do
    field :transactions, list_of(:transaction) do
      arg :from, :string
      arg :to, :string
      arg :transaction_tags, list_of(:transaction_tag_arg)
      arg :member_id, :integer
      resolve fn _, args = %{from: from, to: to, transaction_tags: transaction_tags}, %{context: _context} ->
        from = Date.from_iso8601!(from)
        to = Date.from_iso8601!(to)
        transaction_tag_ids = transaction_tags |> Enum.map(fn %{id: id} -> id end)

        query = from(
          t in Oas.Transactions.Transaction,
          select: t,
          preload: [:transaction_tags, :tokens, :membership, :gocardless_transaction_iid],
          where: t.when <= ^to and t.when >= ^from
            and (t.not_transaction == false or is_nil(t.not_transaction)),
          order_by: [desc: t.when, desc: t.id]
        ) |> (&(case Map.get(args, :member_id) do
          nil -> &1
          member_id -> where(&1, [t], t.who_member_id == ^member_id)
        end)).()
        |> (&(case transaction_tag_ids do
          [] -> &1
          ids -> join(&1, :inner, [t], tt in assoc(t, :transaction_tags), as: :tt)
            |> where([tt: tt], tt.id in ^ids)
            |> group_by([t], t.id)
        end)).()

        result = Oas.Repo.all(query)
        result = result |> Enum.map(fn transaction ->
          warnings = (Map.get(transaction, :gocardless_transaction_iid, %{}) || %{}) |> Map.get(:warnings)
          Map.put(transaction, :warnings, warnings)
        end)
        {:ok, result}
      end
    end
    field :transaction, :transaction do
      arg :id, :integer
      resolve fn _, %{id: id}, _ ->
        transaction = Oas.Repo.get!(Oas.Transactions.Transaction, id)
          |> Oas.Repo.preload(:transaction_tags)
          |> Oas.Repo.preload(:membership)
          |> Oas.Repo.preload(:tokens)
          |> Oas.Repo.preload(:gocardless_transaction_iid)
          |> Oas.Repo.preload(:credit)

        warnings = (Map.get(transaction, :gocardless_transaction_iid, %{}) || %{}) |> Map.get(:warnings)

        {:ok, transaction
          |> Map.put(:warnings, warnings)}
      end
    end
    field :transaction_tags, list_of(:transaction_tag) do
      resolve fn _, _, _ ->
        result = Oas.Repo.all(from(t in Oas.Transactions.TransactionTags, select: t))
        {:ok, result || []}
      end
    end
    field :transaction_auto_tags, list_of(:integer) do
      arg :who, :string
      resolve fn
        _, %{who: nil}, _ ->
          {:ok, []}
        _, %{who: ""}, _ ->
          {:ok, []}
        _, %{who: who}, _ ->
          out = from(ta in Oas.Transactions.TransactionTagAuto,
            where: ta.who == ^who,
            select: ta.transaction_tag_id
          ) |> Oas.Repo.all()
          {:ok, out}
        _, %{}, _ ->
          {:ok, []}
      end
    end
    field :check_duplicate, type: :integer do
      arg :who, non_null(:string)
      arg :amount, non_null(:float)
      arg :when, non_null(:string)
      resolve fn _, %{when: when1, amount: amount, who: who}, _ ->
        result = from(t in Oas.Transactions.Transaction,
          where: t.when == ^when1
            and t.who == ^who
            and t.amount == ^amount,
          limit: 1
        ) |> Oas.Repo.one

        case result do
          nil -> {:ok, nil}
          %{id: id} -> {:ok, id}
        end
      end
    end

    field :pending_transactions, list_of(:pending_transaction) do

      resolve fn _, _, _ ->
        dir = Application.get_env(:oas, :gocardless_backup_dir, "./gocardless_backup")
        pending = dir
          |> File.ls!()
          |> Enum.map(&Path.join(dir, &1))
          |> Enum.filter(&File.regular?/1)
          |> Enum.max_by(&File.stat!(&1).mtime, fn -> nil end)
          |> File.read!()
          |> Jason.decode!()
          |> get_in(["transactions", "pending"])
          |> Enum.map(fn %{
              "bookingDate" => bookingDate,
              "remittanceInformationUnstructured" => remittanceInformationUnstructured,
              "transactionAmount" => %{
                "amount" => transactionAmount
              }
          } ->
            %{
              remittance_information_unstructured: remittanceInformationUnstructured,
              booking_date: bookingDate,
              amount: transactionAmount
            }
          end)

        {:ok, pending}
      end
    end
  end

  defp maybeDoTokens(args, result, when1) do
    if (Map.has_key?(args, :token_quantity) and !Map.has_key?(args, :id)) do
      Oas.Attendance.add_tokens(%{
        member_id: args.who_member_id,
        transaction_id: result.id,
        quantity: args.token_quantity,
        value: args.token_value,
        when1: when1
      })
    end
  end

  defp maybeDoMembership(
    args = %{
      membership_period_id: membership_period_id
    },
    %{
      id: id,
      who_member_id: member_id
    }
  ) do
    _membershipPeriod = Oas.Repo.get!(Oas.Members.MembershipPeriod, membership_period_id)

    _membership = from(m in Oas.Members.Membership, where:
      m.transaction_id == ^id
    ) |> Oas.Repo.one
    |> case do
      nil -> %Oas.Members.Membership{
        transaction_id: id,
        member_id: member_id,
        membership_period_id: membership_period_id
      }
      membership -> membership
    end
    |> Ecto.Changeset.cast(args, [:membership_period_id])
    |> (&(case &1 do
      %{data: %{id: nil}} -> Oas.Repo.insert(&1)
      %{data: %{id: _id}} -> Oas.Repo.update(&1)
    end)).()
  end
  defp maybeDoMembership(args, result) do
    if (!Map.has_key?(args, :membership_period_id)) do
      result
        |> Oas.Repo.preload(:membership)
        |> Ecto.Changeset.cast(%{}, [])
        |> Ecto.Changeset.put_assoc(:membership, nil)
        |> Oas.Repo.update
    end
  end
  # defp maybeDoCredits(args = %{credits_amount: credit_amount}, %{id: id,
  #   who_member_id: member_id,
  #   credit_id: credit_id
  # }, when1) do
  #   from(c in Oas.Credits.Credits, where: c.id == credit_id)
  #   |> case do
  #     nil -> %Oas.Credits.Credits {
  #       amount: credit_amount,
  #       who_member_id: member_id
  #     }
  #   end
  # end

  object :transaction_mutations do
    @desc "Create or Update transaction"
    field :transaction, type: :transaction do
      arg :id, :integer
      arg :what, non_null(:string)
      arg :when, non_null(:string)
      arg :who, :string
      arg :who_member_id, :integer
      arg :training_where_id, :integer
      arg :type, non_null(:string)
      arg :amount, non_null(:float)
      arg :bank_details, :string
      arg :notes, :string
      arg :token_quantity, :integer
      arg :token_value, :float
      arg :transaction_tags, list_of(:transaction_tag_arg)
      arg :auto_tags, list_of(:transaction_tag_arg)
      arg :membership_period_id, :integer
      arg :their_reference, :string
      arg :my_reference, non_null(:string)
      # arg :credit_amount, :float
      arg :credit, :credit_arg

      resolve fn _parent, args, _context ->
        when1 = Date.from_iso8601!(args.when)
        args = %{args | when: when1}

        # doTransactionTags = fn (changeset) ->
        #   case args do
        #     %{transaction_tags: transaction_tags} ->
        #       transaction_tags = transaction_tags
        #         |> Enum.map(fn
        #           %{id: id} -> Oas.Repo.get!(Oas.Transactions.TransactionTags, id)
        #           rest -> rest
        #         end)
        #       out = Ecto.Changeset.put_assoc(changeset, :transaction_tags, transaction_tags)
        #       out
        #     _ -> changeset
        #   end
        # end

        toSave = case Map.get(args, :id) do
          nil -> %Oas.Transactions.Transaction{}
          id -> Oas.Repo.get!(Oas.Transactions.Transaction, id)
            |> Oas.Repo.preload(:transaction_tags)
            |> Oas.Repo.preload(:credit)
        end
        |> Oas.Transactions.Transaction.changeset(args)
        |> Oas.Transactions.TransactionTags.doTransactionTags(args)
        |> Oas.Credits.Credit.doCredit(Map.get(args, :credit, nil))

        result = toSave
          |> (&(case &1 do
            %{data: %{id: nil}} -> Oas.Repo.insert(&1)
            %{data: %{id: _}} -> Oas.Repo.update(&1)
          end)).()
          |> OasWeb.Schema.SchemaUtils.handle_error

        # delete unused tags
        from(
          tt in Oas.Transactions.TransactionTags,
          as: :transaction_tags,
          where: not(exists(
            from(
              c in "transaction_transaction_tags",
              where: c.transaction_tag_id == parent_as(:transaction_tags).id,
              select: 1
            )
          )) # and tt.id in ^removedTransactionTags
        ) |> Oas.Repo.delete_all
        # EO delete unused tags

        case result do
          {:error, error} -> {:error, error}
          {:ok, result} ->
            # Adds tokens
            maybeDoTokens(args, result, when1)
            # Adds membership
            maybeDoMembership(args, result)

            # Auto tag
            if (is_nil(args.who_member_id)) do
              Oas.Transactions.TransactionTagAuto.do_auto_tags(
                toSave.data.who,
                args.who,
                result.transaction_tags,
                Map.get(args, :auto_tags, [])
              )
            end

            {:ok, result}
        end
      end
    end
    field :delete_transaction, type: :success do
      arg :transaction_id, non_null(:integer)
      resolve fn _, %{transaction_id: transaction_id}, _ ->
        Oas.Repo.get!(Oas.Transactions.Transaction, transaction_id) |>
          Oas.Repo.delete!

        # delete unused tags
        from(
          tt in Oas.Transactions.TransactionTags,
          as: :transaction_tags,
          where: not(exists(
            from(
              c in "transaction_transaction_tags",
              where: c.transaction_tag_id == parent_as(:transaction_tags).id,
              select: 1
            )
          )) # and tt.id in ^removedTransactionTags
        ) |> Oas.Repo.delete_all
        # EO delete unused tags

        {:ok, %{success: true}}
      end
    end

    field :transaction_clear_warnings, type: :success do
      arg :transaction_id, non_null(:integer)
      resolve fn _, %{transaction_id: transaction_id}, _ ->
        transaction = Oas.Repo.get!(Oas.Transactions.Transaction, transaction_id)
        |> Oas.Repo.preload(:gocardless_transaction_iid)

        Ecto.Changeset.change(transaction.gocardless_transaction_iid,
          warnings: nil
        )
        |> Oas.Repo.update!()

        {:ok, %{success: true}}
      end
    end

    field :reprocess_transaction, :success do
      arg :id, non_null(:integer)
      arg :who_member_id, non_null(:integer)
      resolve fn _, %{id: id, who_member_id: who_member_id}, _ ->
        member = Oas.Repo.get!(Oas.Members.Member, who_member_id)
        transaction = Oas.Repo.get!(Oas.Transactions.Transaction, id)
        |> Oas.Repo.preload(:credit)
        |> Oas.Repo.preload(:tokens)
        |> Oas.Repo.preload(:membership)
        |> Oas.Repo.preload(:transaction_tags)

        if (transaction.credit != nil || transaction.credit != nil || transaction.tokens != []) do
          raise "This transaciton already has credit or tokens or membership"
        end

        out_transaction = transaction
        |> Ecto.Changeset.cast(%{
          who: member.name,
          who_member_id: who_member_id
        }, [:who, :who_member_id])

        out_transaction = out_transaction
        |> Oas.Gocardless.TransactionsCredits.generate_transaction_credits_2(%{
          transaction_tags: transaction.transaction_tags |> Enum.map(fn %{name: name} -> name end)
        })

        out_transaction |> Oas.Repo.update!()

        {:ok, %{success: true}}
      end
    end

  end
end
