import Ecto.Query, only: [from: 2]

defmodule Oas.Gocardless.Supervisor do
  require Logger
  # restart: :transient
  use Supervisor, restart: :temporary

  # Process.whereis(Oas.Gocardless.AuthServer) |> Process.alive?()
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    config =
      from(
        c in Oas.Config.Config,
        limit: 1
      )
      |> Oas.Repo.one!()

    children =
      case Application.get_env(:oas, :disable_gocardless, false) &&
             config.gocardless_enabled do
        true ->
          Logger.warning("Oas.Gocardless.Supervisor gocardless disabled")
          [Oas.Gocardless.AuthServer]

        false ->
          [
            Oas.Gocardless.AuthServer,
            Oas.Gocardless.TransServer
          ]
      end

    Supervisor.init(children,
      strategy: :rest_for_one,
      # strategy: :one_for_one,
      max_seconds: 86_400,
      max_restarts: 1
    )
  end

  # Oas.Gocardless.Supervisor.restart()
  def restart do
    if Process.whereis(Oas.Gocardless.Supervisor) != nil do
      if Process.whereis(Oas.Gocardless.Supervisor) |> Process.alive?() do
        Supervisor.terminate_child(Oas.Supervisor, Oas.Gocardless.Supervisor)
        Supervisor.start_child(Oas.Supervisor, Oas.Gocardless.Supervisor)
      else
        Supervisor.restart_child(Oas.Supervisor, Oas.Gocardless.Supervisor)
      end
    else
      Supervisor.start_child(Oas.Supervisor, Oas.Gocardless.Supervisor)
    end
  end
end
