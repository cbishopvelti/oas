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
    field :tokens, :integer
    field :is_active, :boolean
    field :is_admin, :boolean
    field :is_reviewer, :boolean

    field :member_details, :member_details
  end


  object :memberWithPassword do
    field :id, :id
    field :name, :string
    field :email, :string
    field :bank_account_name, :string
    field :password, :string
  end

  object :membership_period do
    field :id, :integer
    field :name, :string
    field :from, :string
    field :to, :string
    field :value, :string
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
      resolve fn _, %{show_all: show_all}, _ ->
        query = (from m in Oas.Members.Member, select: m)
        |> (&(case show_all do
          false -> where(&1, [m], m.is_active == true)
          true -> &1
        end)).()

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
        result = Oas.Repo.get!(Oas.Members.Member, member_id) |> Oas.Repo.preload(:member_details)

        tokens = Oas.Attendance.get_token_amount(%{member_id: member_id})

        {:ok, Map.put(result, :tokens, tokens)}
      end
    end
    field :membership_period, :membership_period do
      arg :id, non_null(:integer)
      resolve fn _, %{id: id}, _ -> 
        membershipPeriod = Oas.Repo.get!(Oas.Members.MembershipPeriod, id)
        {:ok, membershipPeriod}
      end
    end
    field :membership_periods, list_of(:membership_period) do
      resolve fn _, _, _ -> 
        membershipPeriods = Oas.Repo.all(from(
          p in Oas.Members.MembershipPeriod,
          select: p,
          order_by: [desc: p.to, desc: p.id]
        ))
        {:ok, membershipPeriods}
      end
    end
  end

  object :member_mutations do
    @desc "Create or update member"
    field :member, type: :memberWithPassword do
      arg :id, :integer
      arg :name, non_null(:string)
      arg :email, non_null(:string)
      arg :bank_reference, :string
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
                  nil -> x
                  _ -> put_in(args, [:member_details, :id], id)
                end
              x -> x
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

        # OLD
        # result = case Map.get(args, :id, nil) do
        #   nil -> length = 12
        #     password = :crypto.strong_rand_bytes(length) |> Base.encode64 |> binary_part(0, length)
        #     attrs = Map.merge(%{password: password}, args)


        #     case Oas.Members.register_member(Map.merge(%{password: password}, args)) do
        #       {:ok, result} -> {:ok, Map.merge(result, %{password: password})}
        #       errored -> OasWeb.Schema.SchemaUtils.handle_error(errored)
        #     end
        #   id -> 
        #     result = Oas.Repo.get!(Oas.Members.Member, id)
        #       |> Ecto.Changeset.cast(args, [:email, :name, :is_active, :is_reviewer, :is_admin, :bank_reference])
        #       |> Ecto.Changeset.validate_required([:name, :email])
        #       |> Oas.Members.Member.validate_email
        #       |> Oas.Repo.update
        #       |> OasWeb.Schema.SchemaUtils.handle_error
        #     result
        # end
      end
    end

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

    @desc "register"
    field :public_register, :success do
      arg :name, non_null(:string)
      arg :email, non_null(:string)
      arg :bank_reference, :string
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