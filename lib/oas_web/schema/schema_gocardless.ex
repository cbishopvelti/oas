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

  object :gocardless_trans_status do
    field :next_run, :string
  end

  object :gocardless_queries do
    field :gocardless_banks, list_of(:gocardless_bank) do
      resolve fn _, _, _  ->
        # data = GenServer.call(Oas.Gocardless.Server, :get_banks)
        data = Oas.Gocardless.get_banks()

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
        # data = GenServer.call(Oas.Gocardless.Server, :get_accounts)

        data = Oas.Gocardless.get_accounts()
        {:ok, data |> Enum.map(fn account_id -> %{id: account_id} end)}
      end
    end
    field :gocardless_trans_status, :gocardless_trans_status do
      resolve fn _, _, _ ->
        if (!is_nil(Process.whereis(Oas.Gocardless.TransServer)) && Process.whereis(Oas.Gocardless.TransServer) |> Process.alive?() ) do
          ms_to_next_run = Process.whereis(Oas.Gocardless.TransServer)
          |> GenServer.call(:status)

          Time.add(Time.utc_now(), ms_to_next_run, :millisecond)
          {:ok, %{
            next_run: Time.add(Time.utc_now(), ms_to_next_run, :millisecond)
          }}
        else
          {:ok, %{
            next_run: nil
          }}
        end
      end
    end
  end

  object :gocardless_mutations do
    field :gocardless_requisitions, :gocardless_requisition do
      arg :institution_id, non_null(:string)
      resolve fn _, %{institution_id: institution_id}, _ ->
        data = GenServer.call(Oas.Gocardless.AuthServer, {:get_requisitions, %{institution_id: institution_id}})

        {:ok, %{
          id: data["id"],
          link: data["link"]
        }}
      end
    end
    field :gocardless_save_requistions, :success do
      resolve fn _, _, %{context: _context} ->
        GenServer.call(Oas.Gocardless.AuthServer, :save_requisitions)

        # DOSNT WORK, doesn't trigger the subscription for some reason
        # mutation = """
        # mutation ($key: String!) {
        #   global_warnings_clear(key: $key) {
        #     key
        #   }
        # }
        # """
        # Absinthe.run(mutation,
        #   OasWeb.Schema,
        #   variables: %{"key" => "gocardless_get_accounts"
        #   },
        #   context: context
        # )

        Oas.Gocardless.delete_warning(:gocardless_get_accounts)

        {:ok, %{
          success: true
        }}
      end
    end
  end

  object :gocardless_subscriptions do
    field :gocardless_trans_status, :success do
      config fn _, _ ->
        {:ok, topic: "*"}
      end

      resolve fn _, _, _ ->
        {:ok, %{success: true}}
      end
    end
  end
end
