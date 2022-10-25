import Ecto.Query, only: [from: 2, where: 3]
defmodule OasWeb.Schema.SchemaMember do
  use Absinthe.Schema.Notation

  object :member do
    field :id, :integer
    field :name, :string
    field :email, :string
    field :tokens, :integer
    field :is_member, :boolean
    field :is_admin, :boolean
  end


  object :memberWithPassword do
    field :id, :id
    field :name, :string
    field :email, :string
    field :password, :string
  end

  object :member_queries do
    field :members, list_of(:member) do
      arg :show_all, :boolean, default_value: false
      resolve fn _, %{show_all: show_all}, _ ->
        query = (from m in Oas.Members.Member, select: m)
        |> (&(case show_all do
          false -> where(&1, [m], m.is_member == true)
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
        query = from(m in Oas.Members.Member, where: m.id == ^member_id)
        result = Oas.Repo.one(query)

        tokens = Oas.Attendance.get_token_amount(%{member_id: member_id})

        {:ok, Map.put(result, :tokens, tokens)}
      end
    end
  end

  object :member_mutations do
    @desc "Create or update member"
    field :new_member, type: :memberWithPassword do
      arg :id, :integer
      arg :name, non_null(:string)
      arg :email, non_null(:string)
      arg :is_member, :boolean
      arg :is_admin, :boolean
      resolve fn _parent, args, context ->
        result = case Map.get(args, :id, nil) do
          nil -> length = 12
            password = :crypto.strong_rand_bytes(length) |> Base.encode64 |> binary_part(0, length)
            case Oas.Members.register_member(Map.merge(%{password: password}, args)) do
              {:ok, result} -> {:ok, Map.merge(result, %{password: password})}
              errored -> OasWeb.Schema.SchemaUtils.handle_error(errored)
            end
          id -> 
            result = Oas.Repo.get!(Oas.Members.Member, id)
              |> Ecto.Changeset.cast(args, [:email, :name, :is_member, :is_admin])
              |> Ecto.Changeset.validate_required([:name, :email])
              |> Oas.Members.Member.validate_email
              |> Oas.Repo.update
              |> OasWeb.Schema.SchemaUtils.handle_error
            result
        end
      end
    end
  end

end