require Protocol
Protocol.derive(Jason.Encoder, LangChain.MessageDelta)

defmodule Oas.Llm.LlmClient do
  alias Oas.Llm.LangChainLlm
  use GenServer

  def start(topic, {from_channel_pid, channel_context}) do
    {:ok, pid} = GenServer.start(
      __MODULE__,
      %{
        topic: topic,
        from_channel_pid: from_channel_pid,
        from_channel_context: channel_context
      }
    )

    {:ok, pid}
  end

  def push_to_in({event, payload}, socket) do
    send(socket.channel_pid,
    %Phoenix.Socket.Message{
      topic: socket.topic,
      event: event,
      ref: nil,
      payload: payload
    })
  end

  @impl true
  def init(init_args) do
    IO.inspect(init_args.from_channel_pid, label: "406")
    Process.monitor(init_args.from_channel_pid)

    state = %{
      topic: init_args.topic,
      llm: %{
        pid: self(),
        name: "assistent"
      },
      from_channel_pid: init_args.from_channel_pid,
      from_channel_context: init_args.from_channel_context
    }
    state = state |> Map.put(:presence_id, Oas.Llm.Utils.get_presence_id(%{assigns: state}))
    state = state |> Map.put(:presence_name, Oas.Llm.Utils.get_presence_name(%{assigns: state}))

    {:ok, lang_chain_llm_pid} = LangChainLlm.start_link(
      self(),
      init_args.from_channel_context.room_pid |> GenServer.call(:messages), # Get messages from the room
      init_args.from_channel_context.member
    )
    state = state |> Map.put(:lang_chain_llm_pid, lang_chain_llm_pid)

    OasWeb.Endpoint.subscribe(init_args.topic)

    OasWeb.Channels.LlmChannelPresence.track(self(), init_args.topic, state.presence_id, %{
      pid: inspect(self()),
      online_at: System.system_time(:second),
      from_channel_pid: state.from_channel_pid,
      presence_name: state.presence_name
    })

    {:ok, state}
  end

  # If our owner dies, shutdown
  @impl true
  def handle_info(
    %{event: "message", payload: %{metadata: %{presence_id: presence_id}} = message},
    %{from_channel_context: %{presence_id: presence_id}} = state)
  do
    IO.puts("406 Ask the llm")
    GenServer.cast(state.lang_chain_llm_pid, {:prompt, message})

    {:noreply, state}
  end
  def handle_info(%{event: "message", payload: message} = broadcast, state) do
    # IO.inspect(message, label: "407 message")
    # IO.inspect(state, label: "408 state")

    GenServer.cast(state.lang_chain_llm_pid, {:message, message})
    {:noreply, state}
  end
  def handle_info({:DOWN, _ref, :process, pid, reason}, %{from_channel_pid: pid} = state) do
    IO.puts("Creating channel ended")
    {:stop, reason, state}
  end
  def handle_info(%{event: "presence_diff"}, state) do
    {:noreply, state}
  end
  def handle_info(stuff, state) do
    IO.inspect(stuff, label: "405 LlmClient handle_info UNHANDLED")
    {:noreply, state}
  end


  @impl true
  # llm -> other channels
  def handle_cast({:broadcast_from, {event, message}}, state) do
    presence_id = Oas.Llm.Utils.get_presence_id(%{assigns: state})
    presence_name = Oas.Llm.Utils.get_presence_name(%{assigns: state})
    message = %{message | metadata: message.metadata |> Map.put(:presence_name, presence_name) |> Map.put(:presence_id, presence_id)}
    OasWeb.Endpoint.broadcast_from!(
      self(),
      state.topic,
      event,
      message
    )
    {:noreply, state}
  end


  @impl true
  def handle_call(:channel_pid, _from_pid, state) do

    {:reply, {self(), %{}}, state}
  end

end
