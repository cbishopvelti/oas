import Ecto.Query, only: [from: 2]

defmodule Oas.Gocardless.TransServer do
  require Logger
  use GenServer, restart: :transient

  # Oas.Gocardless.TransServer.start_link()
  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # How long to wait before trying again after a temporary failure, such as a
  # 503 from GoCardless or a network error.
  def retry_ms, do: Application.get_env(:oas, :gocardless_retry_ms, 60 * 60 * 1000)

  # After this many failed syncs in a row the server stops, and an admin has to
  # press Restart import. With the default hourly retry that is about 6 hours.
  def max_failures, do: Application.get_env(:oas, :gocardless_max_failures, 6)

  def alive? do
    pid = Process.whereis(__MODULE__)
    pid != nil && Process.alive?(pid)
  end

  # Runs a sync now instead of waiting for the next scheduled one.
  def run_now do
    case Process.whereis(__MODULE__) do
      nil -> {:error, "The GoCardless import is not running, restart it first"}
      pid ->
        send(pid, :init)
        :ok
    end
  end

  # Starts the import again after it has stopped. Restarts the whole GoCardless
  # supervisor, so the access token is fetched again too. Starting it runs a sync.
  def restart do
    if alive?() do
      {:error, "The GoCardless import is already running"}
    else
      Oas.Gocardless.delete_warning(:gocardless_stopped)
      Oas.Gocardless.Supervisor.restart()
      Oas.Gocardless.publish_trans_status()

      if alive?() do
        :ok
      else
        {:error, "The GoCardless import didn't start, check the GoCardless config and the server logs"}
      end
    end
  end

  def status do
    case Process.whereis(__MODULE__) do
      nil -> nil
      pid ->
        try do
          GenServer.call(pid, :status, 2_000)
        catch
          # Busy syncing (or just died), so it can't answer right now.
          :exit, _ -> %{running: true}
        end
    end
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
      _args ->
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

    # Lets the admin UI show that a sync is in progress.
    Oas.Gocardless.publish_trans_status()

    case safe_process_transactions() do
      {:ok, _headers} ->
        london_dt = DateTime.now!("Europe/London")
        local_time = DateTime.to_time(london_dt)
        rerun_in_ms_9 = Time.diff(Time.from_iso8601!("09:30:00"), local_time, :millisecond)
        |> Integer.mod(
           86_400_000
        )

        Oas.Gocardless.publish_trans_status()
        timer_ref = Process.send_after(self(), :init, rerun_in_ms_9)
        {:noreply,
          state
          |> Map.put(:timer_ref, timer_ref)
          |> Map.put(:success_on, DateTime.now!("Europe/London"))
          |> Map.delete(:failed_on)
          |> Map.delete(:last_error)
          |> Map.delete(:failures)
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

        Oas.Gocardless.publish_trans_status()

        timer_ref = Process.send_after(self(), :init, rerun_in_ms_reset)
        {:noreply,
          state
          |> Map.put(:timer_ref, timer_ref)
          |> Map.put(:failed_on, DateTime.now!("Europe/London"))
        }
      {:error, error} ->
        failures = Map.get(state, :failures, 0) + 1
        if failures >= max_failures() do
          stopped_on = DateTime.now!("Europe/London") |> Calendar.strftime("%Y-%m-%d %H:%M:%S")
          message = "Gocardless #{inspect(__MODULE__)} stopped on #{stopped_on} after #{failures} failed imports in a row: #{error}"
          Logger.error(message)
          # :normal so the supervisor doesn't restart it straight away; the
          # warning shows why it stopped, next to the Restart import button.
          Oas.Gocardless.send_warning(:gocardless_stopped, message)
          {:stop, :normal, state |> Map.put(:timer_ref, nil)}
        else
          retry_failed(state, error, failures)
        end
      {:unauth_401, error} ->
        Logger.error("Gocardless unathenticated #{error}")
        Oas.Gocardless.send_warning(:gocardless_get_accounts, error)
        {:stop, :normal,
          state |> Map.put(:timer_ref, nil)
        }
    end
  end

  @impl true
  def terminate(reason, _state) do
    Oas.Gocardless.report_stop(__MODULE__, reason)
  end

  @impl true
  def handle_call(:status, _from, state) do
    {
      :reply,
      %{
        running: false,
        next_in: case Map.get(state, :timer_ref) do
          nil -> nil
          ref -> Process.read_timer(ref) || nil
        end,
        success_on: Map.get(state, :success_on),
        failed_on: Map.get(state, :failed_on),
        last_error: Map.get(state, :last_error)
      },
      state
    }
  end

  defp retry_failed(state, error, failures) do
    Logger.error("Gocardless import failed (#{failures}/#{max_failures()}), retrying in #{div(retry_ms(), 1000)}s: #{error}")
    timer_ref = Process.send_after(self(), :init, retry_ms())
    Oas.Gocardless.publish_trans_status()
    {:noreply,
      state
      |> Map.put(:timer_ref, timer_ref)
      |> Map.put(:failed_on, DateTime.now!("Europe/London"))
      |> Map.put(:last_error, error)
      |> Map.put(:failures, failures)
    }
  end

  # A crash inside the sync (an unexpected response, a bug) is logged and
  # retried later instead of stopping the server.
  defp safe_process_transactions do
    try do
      Oas.Gocardless.Transactions.process_transacitons()
    rescue
      e ->
        Logger.error(Exception.format(:error, e, __STACKTRACE__))
        {:error, "#{inspect(e.__struct__)}: #{Exception.message(e)}" |> String.slice(0, 1000)}
    catch
      kind, reason ->
        Logger.error(Exception.format(kind, reason, __STACKTRACE__))
        {:error, "#{kind}: #{inspect(reason)}" |> String.slice(0, 1000)}
    end
  end
end
