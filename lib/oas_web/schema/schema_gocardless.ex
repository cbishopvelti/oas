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
    field :success_on, :string
    field :failed_on, :string
    field :stopped_reason, :string
    field :last_error, :string
    # true while a sync is in progress
    field :running, :boolean
    # true when the import server isn't running and needs a restart
    field :stopped, :boolean
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
        format = fn
          nil -> nil
          x -> Calendar.strftime(x, "%Y-%m-%d %H:%M:%S")
        end

        case Oas.Gocardless.TransServer.status() do
          nil ->
            {:ok, %{
              running: false,
              stopped: true,
              next_run: nil,
              success_on: nil,
              failed_on: "PERMANENT",
              stopped_reason: Oas.Gocardless.stopped_reason()
            }}
          status ->
            {:ok, %{
              running: Map.get(status, :running, false),
              stopped: false,
              next_run: case Map.get(status, :next_in) do
                nil -> nil
                ms_to_next_run -> Time.add(Time.utc_now(), ms_to_next_run, :millisecond)
              end,
              success_on: format.(Map.get(status, :success_on)),
              failed_on: format.(Map.get(status, :failed_on)),
              last_error: Map.get(status, :last_error),
              stopped_reason: nil
            }}
        end
      end
    end
  end

  object :gocardless_mutations do
    field :gocardless_trans_restart, :success do
      resolve fn _, _, _ ->
        case Oas.Gocardless.TransServer.restart() do
          :ok -> {:ok, %{success: true}}
          {:error, message} -> {:error, message}
        end
      end
    end
    field :gocardless_trans_run_now, :success do
      resolve fn _, _, _ ->
        case Oas.Gocardless.TransServer.run_now() do
          :ok -> {:ok, %{success: true}}
          {:error, message} -> {:error, message}
        end
      end
    end
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
