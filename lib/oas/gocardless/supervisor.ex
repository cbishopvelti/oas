defmodule Oas.Gocardless.Supervisor do
  use Supervisor

  # Process.whereis(Oas.Gocardless.AuthServer) |> Process.alive?()
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      Oas.Gocardless.AuthServer,
      Oas.Gocardless.TransServer
    ]

    Supervisor.init(children, strategy: :rest_for_one, max_seconds: 86_400, max_restarts: 1)
  end

  def restart do
    Supervisor.terminate_child(Oas.Gocardless.Supervisor, Oas.Gocardless.AuthServer)
    Supervisor.restart_child(Oas.Gocardless.Supervisor, Oas.Gocardless.AuthServer)

    Supervisor.terminate_child(Oas.Gocardless.Supervisor, Oas.Gocardless.TransServer)
    Supervisor.restart_child(Oas.Gocardless.Supervisor, Oas.Gocardless.TransServer)

    :ok
  end
end
