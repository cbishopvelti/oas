import Ecto.Query, only: [from: 2, where: 3]
defmodule OasWeb.Schema.SchemaMember do
  use Absinthe.Schema.Notation

  object :member_details do
    field :phone, :string
    field :address, :string
    field :dob, :string
    field :nok_name, :string
    field :nok_email, :string
    field :nok_phone, :string
    field :nok_address, :string
    field :agreed_to_tac, :boolean
  end

  object :member do
    field :id, :integer
    field :name, :string
    field :email, :string
    field :bank_account_name, :string
    field :tokens, list_of(:token)
    field :token_count, :integer do
      resolve fn %{id: id}, _, _ ->
        token_count = Oas.Attendance.get_token_amount(%{member_id: id})

        {:ok, token_count}
      end
    end

    field :is_active, :boolean
    field :is_admin, :boolean
    field :is_reviewer, :boolean
    field :inserted_at, :string

    field :member_details, :member_details
    
    field :membership_periods, list_of(:membership_period) do
      resolve fn %{id: id}, _, _ -> 
        member = Oas.Repo.get(Oas.Members.Member, id) |> Oas.Repo.preload(:membership_periods)
        {:ok, member.membership_periods}
      end
    end

    field :memberships, list_of(:membership) do
      resolve fn %{id: id}, _, _ -> 
        member = Oas.Repo.get(Oas.Members.Member, id)
        |> Oas.Repo.preload(memberships: [:transaction, :membership_period])

        {:ok, member.memberships}
      end
    end

    field :transactions, list_of(:transaction) do
      resolve fn %{id: id}, _, _ -> 
        member = Oas.Repo.get(Oas.Members.Member, id) |> Oas.Repo.preload(:transactions)
        {:ok, member.transactions}
      end
    end

    field :member_status, :string do
      resolve fn args = %{id: id}, _, _ ->
        when1 = case args do
          %{member_status_when: when1} ->
            when1
          _ -> Date.utc_today()
        end

        member = from(m in Oas.Members.Member,
          as: :member,
          preload: [membership_periods: ^from(mp in Oas.Members.MembershipPeriod, where: mp.from <= ^when1 and mp.to >= ^when1)],
          select: m,
          where: m.id == ^id
        ) |> Oas.Repo.one!
        {_, membership_type} = Oas.Attendance.check_membership(member)
        {:ok, membership_type}
      end
    end
  end


  object :memberWithPassword do
    field :id, :id
    field :name, :string
    field :email, :string
    field :bank_account_name, :string
    field :password, :string
  end

  input_object :member_details_arg do
    field :phone, non_null(:string)
    field :address, non_null(:string)
    field :dob, non_null(:string)
    field :nok_name, non_null(:string)
    field :nok_email, non_null(:string)
    field :nok_phone, non_null(:string)
    field :nok_address, non_null(:string)
    field :agreed_to_tac, non_null(:boolean)
  end

  object :member_queries do
    field :members, list_of(:member) do
      arg :show_all, :boolean, default_value: false
      arg :member_id, :integer
      resolve fn _, args = %{show_all: show_all}, _ ->
        query = (
          from m in Oas.Members.Member,
          select: m,
          preload: [:tokens],
          order_by: [desc: :id]
        )
        |> (&(case show_all do
          false -> where(&1, [m], m.is_active == true)
          true -> &1
        end)).()
        |> (&(case Map.get(args, :member_id) do
          nil -> &1
          member_id ->
            where(&1, [m], m.id == ^member_id)
        end)).()

        result = Oas.Repo.all(query)

        result = result
        |> Enum.map(fn record ->
          %{id: id} = record
          token_count = Oas.Attendance.get_token_amount(%{member_id: id})
          Map.put(record, :token_count, token_count)
        end)


        {:ok, result}
      end
    end
    field :member, :member do
      arg :member_id, non_null(:integer)
      resolve fn _, %{member_id: member_id}, _ ->

        result = Oas.Repo.get!(Oas.Members.Member, member_id) |> Oas.Repo.preload(:member_details)

        token_count = Oas.Attendance.get_token_amount(%{member_id: member_id})

        {:ok, Map.put(result, :token_count, token_count)}
      end
    end
  end

  object :member_mutations do
    @desc "Create or update member"
    field :member, type: :memberWithPassword do
      arg :id, :integer
      arg :name, non_null(:string)
      arg :email, non_null(:string)
      arg :bank_account_name, :string
      arg :is_active, :boolean
      arg :is_reviewer, :boolean
      arg :is_admin, :boolean
      arg :member_details, :member_details_arg
      resolve fn _parent, args, context ->

        toSave = case Map.get(args, :id) do
          nil ->
            length=12
            password = :crypto.strong_rand_bytes(length) |> Base.encode64 |> binary_part(0, length)
            attrs = Map.merge(%{password: password}, args)
            %Oas.Members.Member{}
            |> Oas.Members.Member.registration_changeset(attrs)
          id ->
            member = Oas.Repo.get!(Oas.Members.Member, id) |> Oas.Repo.preload(:member_details)
            attrs = case member do
              x = %{member_details: %{id: id}} ->
                case Map.get(args, :member_details) do
                  nil -> args
                  _ -> put_in(args, [:member_details, :id], id)
                end
              x -> args
            end
            member |> Oas.Members.Member.changeset(attrs)
        end        

        result = toSave
        
        |> (&(case Map.get(args, :member_details) do
          nil -> &1
          _ -> Ecto.Changeset.cast_assoc(&1, :member_details)
        end)).()
        |> (&(case &1 do
            %{data: %{id: nil}} -> Oas.Repo.insert(&1)
            _ -> Oas.Repo.update(&1)
          end)).()
        |> OasWeb.Schema.SchemaUtils.handle_error()

        case result do
          {:error, error} -> {:error, error}
          {:ok, result} -> {:ok, result}
        end
      end
    end
    field :delete_member, type: :success do
      arg :member_id, non_null(:integer)
      resolve fn _, %{member_id: member_id}, _ ->
        Oas.Repo.get!(Oas.Members.Member, member_id) |> Oas.Repo.delete!

        {:ok, %{success: true}}
      end
    end

    @desc "register"
    field :public_register, :success do
      arg :name, non_null(:string)
      arg :email, non_null(:string)
      arg :member_details, non_null(:member_details_arg)
      resolve fn _, args, _ ->
        length=12
        password = :crypto.strong_rand_bytes(length) |> Base.encode64 |> binary_part(0, length)
        attrs = Map.merge(%{password: password, is_active: true}, args)

        result = %Oas.Members.Member{}
        |> Oas.Members.Member.registration_changeset(attrs)
        |> Ecto.Changeset.cast_assoc(:member_details)
        |> Oas.Repo.insert

        case result do
          {:ok, result} -> {:ok, %{success: true}}
          errored -> OasWeb.Schema.SchemaUtils.handle_error(errored)
        end
      end
    end
  end

end