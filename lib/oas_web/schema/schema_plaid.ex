defmodule OasWeb.Schema.SchemaPlaid do
  use Absinthe.Schema.Notation

  object :plaid_queries do
    field :plaid_link_token, :string do
      resolve fn _, _, _ ->

        {:ok, link_token} = Oas.Plaid.Link.get_link_token()

        {:ok, link_token}
      end
    end
  end

  object :plaid_mutations do
    field :plaid_exchange_public_token, :success do
      arg :public_token, non_null(:string)
      resolve fn _, args, _ ->
        IO.inspect(args, label: "007")

        # Exchange
        Oas.Plaid.Link.exchange(Map.get(args, :public_token))

        {:ok, %{success: true}}
      end
    end
  end

end
