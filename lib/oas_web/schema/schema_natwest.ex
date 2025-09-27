defmodule OasWeb.Schema.SchemaNatwest do
  use Absinthe.Schema.Notation

  object :natwest_link do
    field :link, :string
  end

  object :natwest_mutations do
    field :natwest_generate_link, :natwest_link do

      resolve fn _, _, _ ->
        Oas.Natwest.Auth.access_token();
        {:ok, link} = Oas.Natwest.Auth.consent()

        {:ok, %{
          link: link
        }}
      end
    end

    field :natwest_exchange_code, :success do
      arg :code, non_null(:string)
      arg :id_token, :string
      resolve fn _, args, _ ->
        Oas.Natwest.Auth.exchange_code(Map.get(args, :code))
      end
    end
  end

end
