defmodule Oas.Failover.FailoverServer do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    :net_kernel.monitor_nodes(true, node_type: :visible)

    :ra.start() |> IO.inspect(label: "300")

    :ra.start_cluster(:default, :failover, {:module, Oas.Failover.Machine, %{}}, [Node.self() | Node.list()])
    # |> IO.inspect(label: "301")

    {:ok, %{}}
  end

  @impl true
  def handle_info({:nodeup, node, info}, state) do
    # handle node join
    {:noreply, state}
  end

  @impl true
  def handle_info({:nodedown, node, info}, state) do

    IO.inspect(node, label: ":nodedown 201.1")
    IO.inspect(info, label: ":nodedown 201.2")

    # handle node disconnect
    {:noreply, state}
  end

end
