import Ecto.Query, only: [from: 2]

defmodule Oas.Gocardless.TransServer do
  use GenServer, restart: :transient

  # Oas.Gocardless.TransServer.start_link()
  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @impl true
  def init(_) do
    IO.puts("Oas.Gocardless.TransServer Server init")
    pid = Process.whereis(Oas.Gocardless.AuthServer)
    account_id = from(cc in Oas.Config.Config, select: cc.gocardless_account_id) |> Oas.Repo.one()

    case {pid && Process.alive?(pid), account_id} do
      {true, account_id } when account_id != nil -> IO.puts("alive, start")
        Process.send_after(self(), :init, 0)
        {:ok, %{}}
      _ ->
        IO.puts("Not alive, don't start")
        :ignore
    end
  end

  @impl true
  def handle_info(:init, state) do
    if (Map.has_key?(state, :timer_ref)) do
      Process.cancel_timer(state.timer_ref)
    end

    {:ok, headers} = Oas.Gocardless.Transactions.process_transacitons()

    remaining = List.keyfind!(headers, "http_x_ratelimit_account_success_remaining", 0) |> elem(1) |> String.to_integer()
    reset_seconds = List.keyfind!(headers, "http_x_ratelimit_account_success_reset", 0) |> elem(1) |> String.to_integer()

    timeout = div(reset_seconds, (remaining + 1))

    timer_ref = Process.send_after(self(), :init, timeout)
    {:noreply,
      %{
        timer_ref: timer_ref
      }
    }
  end
end
