import Ecto.Query, only: [from: 2]

defmodule Oas.Gocardless.TransServer do
  require Logger
  use GenServer, restart: :transient

  # Oas.Gocardless.TransServer.start_link()
  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # IEx.Helpers.pid("#PID<0.422.0>") |> Process.send_after(:init, 0)
  @impl true
  def init(_) do
    pid = Process.whereis(Oas.Gocardless.AuthServer)
    account_id = from(cc in Oas.Config.Config, select: cc.gocardless_account_id) |> Oas.Repo.one()
    case {pid && Process.alive?(pid), account_id} do
      {true, account_id } when account_id != nil ->
        # IO.puts("alive, start")
        Logger.info("Oas.Gocardless.TransServer.init success #{inspect(self())}")
        Process.send_after(self(), :init, 0) # DEBUG ONLY, uncomment
        {:ok, %{}}
      args ->
        IO.inspect(args, label: "001 error")
        Logger.warning("Oas.Gocardless.TransServer.init failed, didn't start")
        :ignore
    end
  end

  @impl true
  def handle_info(:init, state) do
    if (Map.has_key?(state, :timer_ref)) do
      Process.cancel_timer(state.timer_ref)
    end

    # headers = [ # DEBUG, remove
    #   {"http_x_ratelimit_account_success_remaining", "3"},
    #   {"http_x_ratelimit_account_success_reset", "86400"}
    # ]
    # Process.sleep(12_000)

    case Oas.Gocardless.Transactions.process_transacitons() do
      {:ok, _headers} ->
        london_dt = DateTime.now!("Europe/London")
        local_time = DateTime.to_time(london_dt)
        rerun_in_ms_9 = Time.diff(Time.from_iso8601!("09:30:00"), local_time, :millisecond)
        |> Integer.mod(
           86_400_000
        )

        Absinthe.Subscription.publish(OasWeb.Endpoint, %{}, gocardless_trans_status: "*")
        timer_ref = Process.send_after(self(), :init, rerun_in_ms_9)
        {:noreply,
          state
          |> Map.put(:timer_ref, timer_ref)
          |> Map.put(:success_on, DateTime.now!("Europe/London"))
          |> Map.delete(:failed_on)
        }
      {:to_many_requests, headers} ->
        remaining = List.keyfind!(headers, "http_x_ratelimit_account_success_remaining", 0) |> elem(1) |> String.to_integer()
        reset_seconds = List.keyfind!(headers, "http_x_ratelimit_account_success_reset", 0)
          |> elem(1)
          |> String.to_integer()
          |> Kernel.+(60) # Insure we have a little buffer.

        Logger.info("Gocardless :to_many_requests remaining #{remaining}")
        Logger.info("Gocardless :to_many_requests reset_seconds #{reset_seconds}")

        rerun_in_ms_reset = reset_seconds * 1000

        Absinthe.Subscription.publish(OasWeb.Endpoint, %{}, gocardless_trans_status: "*")

        timer_ref = Process.send_after(self(), :init, rerun_in_ms_reset)
        {:noreply,
          state
          |> Map.put(:timer_ref, timer_ref)
          |> Map.put(:failed_on, DateTime.now!("Europe/London"))
        }
      {:unauth_401, error} ->
        Logger.error("Gocardless unathenticated #{error}")
        Oas.Gocardless.send_warning(:gocardless_get_accounts, error)
        {:stop, :normal,
          state |> Map.put(:timer_ref, nil)
        }
    end
  end

  @impl true
  def handle_call(:status, _from, state) do

    case Map.get(state, :timer_ref, nil) do
      nil -> {:reply, nil, state}
      ref -> {
        :reply,
        %{
          next_in: Process.read_timer(ref),
          success_on: Map.get(state, :success_on),
          failed_on: Map.get(state, :failed_on)
        },
        state
      }
    end
  end
end
