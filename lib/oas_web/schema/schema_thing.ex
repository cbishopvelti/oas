import Ecto.Query, only: [from: 2]
defmodule OasWeb.Schema.SchemaThing do
  use Absinthe.Schema.Notation

  object :thing do
    field :id, :integer
    field :what, :string
    field :value, :string
    field :when, :string
    field :credits, list_of(:credit)
  end

  object :thing_queries do
    field :things, list_of(:thing) do
      arg :from, :string
      arg :to, :string
      middleware OasWeb.Schema.MiddlewareQuery
      resolve fn _, args, _ ->
        query = from(
          t in Oas.Things.Thing,
          select: t,
          order_by: [desc: t.when, desc: t.id]
        )

        query = case args do
          %{from: from, to: to} ->
            from_date = Date.from_iso8601!(from)
            to_date = Date.from_iso8601!(to)
            from(t in query, where: t.when >= ^from_date and t.when <= ^to_date)
          _ -> query
        end

        result = Oas.Repo.all(query)
        {:ok, result}
      end
    end

    field :thing, :thing do
      arg :id, non_null(:integer)
      middleware OasWeb.Schema.MiddlewareQuery
      resolve fn _, %{id: id}, _ ->
        result = Oas.Repo.get(Oas.Things.Thing, id)
        |> Oas.Repo.preload([credits: [:member]])

        case result do
          nil -> {:error, "Thing with id #{id} not found"}
          thing -> {:ok, thing}
        end
      end
    end
  end

  object :thing_mutations do
    field :thing, type: :thing do
      arg :id, :integer
      arg :what, non_null(:string)
      arg :value, :string
      arg :when, non_null(:string)
      resolve fn _parent, args, _ ->
        thing = case Map.get(args, :id) do
          nil -> %Oas.Things.Thing{}
          id -> Oas.Repo.get!(Oas.Things.Thing, id)
        end

        args = %{args | when: Date.from_iso8601!(args.when)}

        thing
        |> Ecto.Changeset.cast(args, [:what, :value, :when])
        |> (&(case &1 do
          %{data: %{id: nil}} -> Oas.Repo.insert(&1)
          %{data: %{id: _}} -> Oas.Repo.update(&1)
        end)).()
        |> OasWeb.Schema.SchemaUtils.handle_error
      end
    end

    field :thing_delete_debit, type: :success do
      arg :credit_id, non_null(:integer)
      resolve fn _, %{credit_id: credit_id}, _ ->
        case Oas.Repo.get(Oas.Credits.Credit, credit_id) do
          nil -> {:error, "Credit with id #{credit_id} not found"}
          credit ->
            Oas.Repo.delete!(credit)
            {:ok, %{success: true}}
        end
      end
    end

    field :thing_add_debit, type: :success do
      arg :id, non_null(:integer)
      arg :who_member_id, non_null(:integer)
      resolve fn _, %{id: id, who_member_id: who_member_id}, _ ->
        thing = Oas.Repo.get(Oas.Things.Thing, id)
        now = Date.utc_today()

        %Oas.Credits.Credit{}
        |> Ecto.Changeset.cast(%{
          what: "#{thing.what}",
          when: now,
          amount: Decimal.sub("0.0", thing.value),
          who_member_id: who_member_id,
          thing_id: id
        }, [:what, :when, :amount, :who_member_id, :thing_id]) |> Oas.Repo.insert()

        {:ok, %{success: true}}
      end
    end
  end
end
