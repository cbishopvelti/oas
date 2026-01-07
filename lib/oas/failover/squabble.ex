defmodule Oas.Failover.Squabble do

  # use GenServer



  # @impl true
  # def init(args) do

  #   {:ok, args}
  # end

  @behaviour Suabble.Leader

  @impl true
  def leader_selected(term) do
    IO.inspect(term, label: "401 leader_selected")
  end

  @impl true
  def node_down() do
    IO.puts("042 node_down")
    :ok
  end

  @impl true
  def not_leader(term) do
    IO.puts("403 not_leader")
    :ok
  end
end
