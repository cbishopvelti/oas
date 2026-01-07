defmodule Oas.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do

    Application.ensure_all_started(:ra)

    topologies = [
      oas: [
        strategy: Cluster.Strategy.Epmd,
        config: [hosts: [:"n1@phoenix-n1", :"n2@phoenix-n2", :"n3@phoenix-n3"]],
      ]
    ]

    children = [
      {Cluster.Supervisor, [topologies, [name: Oas.ClusterSupervisor]]},
      # Start the Ecto repository
      Oas.Repo,
      # Start the Telemetry supervisor
      OasWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Oas.PubSub},
      OasWeb.Channels.LlmChannelPresence,
      {Registry, keys: :unique, name: OasWeb.Channels.LlmRegistry},
      # Start a worker by calling: Oas.Worker.start_link(arg)
      # {Oas.Worker, arg}
      Oas.BackupJob,
      Oas.Gocardless.Supervisor,
      Oas.Trainings.RecurringServer,
      {Task.Supervisor, name: Oas.TaskSupervisor},
      # Start the Endpoint (http/https)
      OasWeb.Endpoint,
      {Absinthe.Subscription, OasWeb.Endpoint},
      # %{
      #   id: :pg,
      #   start: {:pg, :start_link, []}
      # },
      # {Squabble, [subscriptions: [Oas.Failover.Squabble], size: 1]}
      # Oas.Failover.FailoverServer
    ]

    :ets.new(:user_table, [:named_table, :public, :set, read_concurrency: true])
    :ets.new(:global_warnings, [:set, :public, :named_table])

    maybe_claim_vip()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Oas.Supervisor, max_restarts: 1]
    Supervisor.start_link(children, opts)
  end

  def maybe_claim_vip() do
    if (Node.self() == :"n1@phoenix-n1") do
      IO.puts("001 maybe_claim_vip ------------")
      System.cmd("ip", ["addr", "add", "172.29.0.20", "dev", "eth0"])
      System.cmd("arping", ["-U", "-c", "3", "-I", "eth0", "172.29.0.20"])
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    OasWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
