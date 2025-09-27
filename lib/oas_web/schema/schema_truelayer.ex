import Ecto.Query, only: [from: 2]

defmodule OasWeb.Schema.SchemaTruelayer do
  use Absinthe.Schema.Notation

  object :truelayer_config do
    field :client_id, :string
    field :client_secret, :string
  end

  object :truelayer_queries do
    field :truelayer_config, :truelayer_config do
      resolve fn _, _, _ ->
        result = from(cc in Oas.Truelayer.Config, select: cc) |> Oas.Repo.one
        {:ok, result}
      end
    end
  end

  object :truelayer_mutations do
    field :truelayer_config, :success do
      resolve fn _, _, _ ->
        {:ok, %{
          success: true
        }}
      end
    end
    field :truelayer_callback, :success do
      arg :code, non_null(:string)
      resolve fn _, args, _ ->
        IO.inspect(args, label: "005")

        Oas.Truelayer.Auth.handle_callback(Map.get(args, :code))
        {:ok, %{
          success: true
        }}
      end
    end
  end

end
