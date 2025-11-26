defmodule Oas.Llm.TestA do
  use GenServer

  # pid = Oas.Llm.TestA.start_link()
  # pid |> GenServer.cast(:test_error)

  # Oas.Llm.TestA.start_link() |> GenServer.cast(:test_error)
  def start_link() do
    GenServer.start_link(__MODULE__, %{}) |> elem(1)
  end

  def init(_args) do
    Process.flag(:trap_exit, true)
    {:ok, pid} = Oas.Llm.TestB.start_link()
    # Process.monitor(pid)
    {:ok, pid}
  end

  def handle_cast(:test_error, state) do
    state |> GenServer.cast(:may_error)
    {:noreply, state}
  end

  def handle_info(message, state ) do
    IO.inspect(message, label: "THIS SHOULD HAPPEN")
    {:noreply, state}
  end
  def terminate(reason, _state) do
    IO.inspect(reason, label: "maybe should happen")
  end
end

defmodule Oas.Llm.TestB do

  def start_link() do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do

    {:ok, state}
  end

  def handle_cast(:may_error, state) do
    {:stop, :my_error, state}
  end
end
