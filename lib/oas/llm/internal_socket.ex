defmodule Oas.Llm.InternalSocket do
  @behaviour Phoenix.Socket.Transport

  def child_spec(opts) do
    # We won't spawn any process, so let's ignore the child spec
    :ignore
  end

  def connect(state) do
    # Callback to retrieve relevant data from the connection.
    # The map contains options, params, transport and endpoint keys.
    {:ok, state}
  end

  def init(state) do
    # Now we are effectively inside the process that maintains the socket.
    {:ok, state}
  end

  # def handle_in({text, _opts}, state) do
  #   {:reply, :ok, {:text, text}, state}
  # end
  def handle_in(message, state) do
    {:reply, :ok, message, state}
  end

  def handle_info(message, state) do
    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end
end
