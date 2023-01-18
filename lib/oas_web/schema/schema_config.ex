import Ecto.Query, only: [from: 2]
defmodule OasWeb.Schema.SchemaConfig do
  use Absinthe.Schema.Notation
  
  object :config_token do
    field :id, :integer
    field :value, :string
    field :quantity, :integer
  end

  object :config_config do
    field :id, :integer
    field :token_expiry_days, :integer
    field :temporary_trainings, :integer
    field :bacs, :string
    field :enable_booking, :boolean
    field :name, :string
  end

  object :public_config_config do
    field :enable_booking, :boolean
  end

  object :config_queries do
    field :config_token, :config_token do
      arg :token_quantity, non_null(:integer)
      resolve fn _, %{token_quantity: token_quantity}, _ ->
        result = from(ct in Oas.Config.Tokens, where: ct.quantity <= ^token_quantity, order_by: [desc: ct.quantity], limit: 1)
          |> Oas.Repo.one
        {:ok, result}
      end
    end
    field :config_tokens, list_of(:config_token) do
      resolve fn _, _, _ -> 
        results = from(ct in Oas.Config.Tokens, select: ct, order_by: [asc: ct.quantity])
          |> Oas.Repo.all

        {:ok, results}
      end
    end
    field :config_config, :config_config do
      resolve fn _, _, _ ->
        result = from(cc in Oas.Config.Config, select: cc)
          |> Oas.Repo.one

        {:ok, result}
      end
    end
    field :public_config_config, :public_config_config do
      resolve fn _, _, _ ->
        IO.puts("001 SHOULD HAPPEN")

        result = from(cc in Oas.Config.Config, select: cc)
          |> Oas.Repo.one

        IO.inspect(result)

        {:ok, result}
      end
    end
  end

  object :config_mutations do
    field :save_config_token, :config_token do
      arg :quantity, non_null(:integer)
      arg :value, non_null(:string)
      resolve fn _, args, _ -> 
        %Oas.Config.Tokens{}
        |> Ecto.Changeset.cast(args, [:quantity, :value])
        |> Oas.Repo.insert
        |> OasWeb.Schema.SchemaUtils.handle_error
      end
    end
    field :delete_config_token, :success do
      arg :id, non_null(:integer)
      resolve fn _, %{id: id}, _ ->
        result = Oas.Repo.get!(Oas.Config.Tokens, id) |>
          Oas.Repo.delete!

        {:ok, %{success: true}}
      end
    end
    field :save_config_config, :config_config do
      arg :token_expiry_days, :integer
      arg :temporary_trainings, :integer
      arg :bacs, :string
      arg :enable_booking, :boolean
      arg :name, :string
      resolve fn _, args, _ -> 

        from(cc in Oas.Config.Config, select: cc) 
        |> Oas.Repo.one
        |> Ecto.Changeset.cast(args, [:token_expiry_days, :temporary_trainings, :bacs, :enable_booking, :name])
        |> Oas.Repo.update
        |> OasWeb.Schema.SchemaUtils.handle_error
      end
    end
  end
end



