import Ecto.Query, only: [from: 2, where: 3]
defmodule OasWeb.Schema.SchemaGocardless do
  use Absinthe.Schema.Notation

  object :gocardless_bank do
    field :id, :string
    field :name, :string
  end

  object :gocardless_requisition do
    field :id, :string
    field :link, :string
  end

  object :gocardless_account do
    field :id, :string
  end

  object :gocardless_queries do
    field :gocardless_banks, list_of(:gocardless_bank) do
      resolve fn _, _, _  ->
        data = GenServer.call(Oas.Gocardless.Server, :get_banks)

        {:ok, Enum.map(data, fn %{"id" => id, "name" => name} ->
          %{
            id: id,
            name: name
          }
        end)}
      end
    end
    field :gocardless_accounts, list_of(:gocardless_account) do
      resolve fn _, _, _ ->
        data = GenServer.call(Oas.Gocardless.Server, :get_accounts)
        {:ok, data |> Enum.map(fn account_id -> %{id: account_id} end)}
      end
    end
  end

  object :gocardless_mutations do
    field :gocardless_requisitions, :gocardless_requisition do
      arg :institution_id, non_null(:string)
      resolve fn _, %{institution_id: institution_id}, _ ->
        data = GenServer.call(Oas.Gocardless.Server, {:get_requisitions, %{institution_id: institution_id}})

        {:ok, %{
          id: data["id"],
          link: data["link"]
        }}
      end
    end
    field :gocardless_save_requistions, :success do
      resolve fn _, _, _ ->
        GenServer.call(Oas.Gocardless.Server, :save_requistions)

        {:ok, %{
          success: true
        }}
      end
    end
  end
end
