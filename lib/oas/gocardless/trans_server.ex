import Ecto.Query, only: [from: 2]

defmodule Oas.Gocardless.TransServer do
  require Logger
  use GenServer, restart: :transient

  # Oas.Gocardless.TransServer.start_link()
  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @impl true
  def init(_) do
    pid = Process.whereis(Oas.Gocardless.AuthServer)
    account_id = from(cc in Oas.Config.Config, select: cc.gocardless_account_id) |> Oas.Repo.one()
    case {pid && Process.alive?(pid), account_id} do
      {true, account_id } when account_id != nil ->
        # IO.puts("alive, start")
        Logger.info("Oas.Gocardless.TransServer.init success")
        Process.send_after(self(), :init, 0)
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
      {:ok, headers} ->
        remaining = List.keyfind!(headers, "http_x_ratelimit_account_success_remaining", 0) |> elem(1) |> String.to_integer()
        reset_seconds = List.keyfind!(headers, "http_x_ratelimit_account_success_reset", 0)
          |> elem(1)
          |> String.to_integer()
          |> Kernel.+(60) # Insure we have a little buffer.

        timeout = div(reset_seconds, (remaining + 1))
        timeout = if Mix.env() != :test do
          Enum.max([timeout, 3_600])
        else
          timeout
        end
        _timeout_ms = timeout * 1000
        # timer_ref = Process.send_after(self(), :init, timeout_ms)


        rerun_in_ms = if (remaining > 0) do
          london_dt = DateTime.now!("Europe/London")
          local_time = DateTime.to_time(london_dt)

          Time.diff(Time.from_iso8601!("09:30:00"), local_time, :millisecond)
          |> Integer.mod(
             86_400_000
          )
        else
          reset_seconds * 1000
        end

        Absinthe.Subscription.publish(OasWeb.Endpoint, %{}, gocardless_trans_status: "*")

        # Once a day
        timer_ref = Process.send_after(self(), :init, rerun_in_ms)
        {:noreply,
          %{
            timer_ref: timer_ref
          }
        }
      {:unauth_401, error} ->
        Logger.error("Gocardless unathenticated #{error}")
        Oas.Gocardless.send_warning(:gocardless_get_accounts, error)
        {:stop, :normal, %{timer_ref: nil}}
    end


  end

  @impl true
  def handle_call(:status, _from, state) do
    Process.read_timer(state.timer_ref)

    {:reply, Process.read_timer(state.timer_ref), state}
  end
end
