import Ecto.Query, only: [from: 2, where: 3, dynamic: 2]
defmodule OasWeb.Schema.SchemaMembershipPeriod do
  use Absinthe.Schema.Notation

  object :membership_period do
    field :id, :integer
    field :name, :string
    field :from, :string
    field :to, :string
    field :value, :string
    field :members, list_of(:member) do
      resolve fn %{id: id}, _, _ ->
        membershipPeriod = Oas.Repo.get(Oas.Members.MembershipPeriod, id)
          |> Oas.Repo.preload(:members)
          
        members = membershipPeriod.members
          |> Enum.map(fn member -> Map.delete(member, :tokens) end)
          |> Enum.map(fn record ->
            %{id: id} = record
            tokens = Oas.Attendance.get_token_amount(%{member_id: id})
            Map.put(record, :tokens, tokens)
          end)

        {:ok, members}
      end
    end
  end

  object :membership_period_queries do
    field :membership_period, :membership_period do
      arg :id, non_null(:integer)
      resolve fn _, %{id: id}, _ -> 
        membershipPeriod = Oas.Repo.get!(Oas.Members.MembershipPeriod, id)
        {:ok, membershipPeriod}
      end
    end
    field :membership_periods, list_of(:membership_period) do
      arg :member_id, :integer
      arg :transaction_id, :integer
      resolve fn _, args, _ -> 
        query = from(
          p in Oas.Members.MembershipPeriod,
          as: :membership_periods,
          select: p,
          order_by: [desc: p.to, desc: p.id]
        )
        |> (&(case args do 
          %{member_id: member_id} when member_id != nil ->

            transaction_id = Map.get(args, :transaction_id, 0)

            where(&1, [p], 
              not(exists(from(
                m in Oas.Members.Membership,
                where: m.member_id == ^member_id and parent_as(:membership_periods).id == m.membership_period_id and (
                  is_nil(m.transaction_id) or m.transaction_id != ^transaction_id
                )
              )))
            )
          _ ->
            &1
        end)).()
        
        membershipPeriods = Oas.Repo.all(query)

        {:ok, membershipPeriods}
      end
    end
  end

  object :membership_period_mutations do
    @desc "Create or update membership period"
    field :membership_period, type: :membership_period do
      arg :id, :integer
      arg :name, non_null(:string)
      arg :from, non_null(:string)
      arg :to, non_null(:string)
      arg :value, non_null(:string)   
      resolve fn _parent, args, _ ->
        membershipPeriod = case Map.get(args, :id, nil) do
          nil -> %Oas.Members.MembershipPeriod{}
          id -> Oas.Repo.get!(Oas.Members.MembershipPeriod, id)
        end

        args = %{args |
          to: Date.from_iso8601!(args.to),
          from: Date.from_iso8601!(args.from)
          # value: Decimal.from_float(args.value)
        }

        result = membershipPeriod |>
          Ecto.Changeset.cast(args, [:to, :from, :name, :value])
          |> (&(case &1 do
            %{data: %{id: nil}} -> Oas.Repo.insert(&1)
            %{data: %{id: _}} -> Oas.Repo.update(&1)
          end)).()
          |> OasWeb.Schema.SchemaUtils.handle_error

        result
      end
    end

    @desc "Delete membership"
    field :delete_membership, type: :success do
      arg :membership_period_id, non_null(:integer)
      arg :member_id, non_null(:integer)
      resolve fn _, %{membership_period_id: membership_period_id, member_id: member_id}, _ -> 
        from(m in Oas.Members.Membership, 
          where: m.membership_period_id == ^membership_period_id and m.member_id == ^member_id
        ) |> Oas.Repo.delete_all

        {:ok, %{success: true}}
      end
    end
  end
end