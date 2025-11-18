defmodule Oas.Llm.LlmClient do
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
    state = state |> Map.put(:presence_id, OasWeb.Channels.LlmChannel.get_presence_id(%{assigns: state}))
    state = state |> Map.put(:presence_name, OasWeb.Channels.LlmChannel.get_presence_name(%{assigns: state}))

    OasWeb.Endpoint.subscribe(init_args.topic)

    OasWeb.Channels.LlmChannelPresence.track(self(), init_args.topic, state.presence_id, %{
      pid: inspect(self()),
      online_at: System.system_time(:second),
      from_channel_pid: state.from_channel_pid,
      presence_name: state.presence_name
    })

    {:ok, state}
  end



  def init_old(init_args) do
    Process.monitor(init_args.from_channel_pid)
    # SO setting up channel
    socket = %Phoenix.Socket{
      transport: :internal,
      endpoint: OasWeb.Endpoint,
      # handler: Oas.PublicSocket,
      handler: Oas.Llm.InternalSocket,
      pubsub_server: Oas.PubSub,
      assigns: %{
        llm: %{
          pid: self(),
          name: "assistent"
        },
        from_channel_pid: init_args.from_channel_pid,
        from_channel_context: init_args.from_channel_context
      },
      channel: OasWeb.Channels.LlmChannel,
      topic: init_args.topic,
      serializer: Phoenix.Socket.V2.JSONSerializer,
      transport_pid: self()
    }

    # OasWeb.Channels.LlmChannel.join(init_args.topic, %{}, socket)
    # result = OasWeb.Channels.LlmChannel.start_link({OasWeb.Channels.LlmChannel, :start_link, [{OasWeb.Endpoint, {self(), make_ref()}}]})
    ref = make_ref()
    from = {self(), ref}
    {:ok, channel_pid} = OasWeb.Channels.LlmChannel.start_link({OasWeb.Endpoint, from})


    send(
      channel_pid,
      {
        Phoenix.Channel,
        %{},
        from,
        socket # Socket needs a __channel__
      }
    )
    mon_ref = Process.monitor(channel_pid)
    receive do
      {^ref, {:ok, reply}} ->
        Process.demonitor(mon_ref, [:flush])
        {:ok, reply, channel_pid}

      {^ref, {:error, reply}} ->
        Process.demonitor(mon_ref, [:flush])
        {:error, reply}

      {:DOWN, ^mon_ref, _, _, reason} ->
        Logger.error(fn -> Exception.format_exit(reason) end)
        {:error, %{reason: "join crashed"}}
    end
    socket = GenServer.call(channel_pid, :socket) # Added joined: true
    socket = Phoenix.Socket.assign(socket, :channel_pid, channel_pid)

    # EO Setting up channel

    # Task.async(fn () ->
    #   Process.sleep(6000)
    #   # GenServer.cast(pid, {:send_prompt, {}})
    #   push_to_in({"test_in", %{"test1" => "test2"}}, socket)
    #   {:ok, :wat}
    # end)

    # SO setting up the llm
    {:ok, chain_pid} = Oas.Llm.LangChainLlm.start_link(
      self(),
      init_args.from_channel_context.room_pid |> GenServer.call(:messages), # Get the messages from the room
      init_args.from_channel_context.current_member
    )
    socket = Phoenix.Socket.assign(socket, :chain_pid, chain_pid)
    # EO setting up the llm



    {:ok, socket}
  end

  defp handle_in("prompt", message, socket) do
    IO.inspect(message, label: "406 LlmClient prompt")
    IO.inspect(socket.assigns, label: "407 LlmClient prompt")
    # Is this prompt for us?
    GenServer.cast(socket.assigns.chain_pid, {
      :prompt,
        LangChain.Message.new!(Oas.Llm.Utils.decode(message))
    })

    {:noreply, socket}
  end
  defp handle_in("messages", _messages, socket) do
    # TODO, nothing for now as messages are set at startup.
    {:noreply, socket}
  end
  defp handle_in("presence_diff", _messages, socket) do
    # if our owner dies, we should also die, but we're also linked to our owner, so we'd probably die anyway.
    {:noreply, socket}
  end
  defp handle_in("presence_state", _message, socket) do
    {:noreply, socket}
  end
  defp handle_in("participants", _message, socket) do
    {:noreply, socket}
  end
  defp handle_in("delta", _message, socket) do
    # We don't care about delta
    {:noreply, socket}
  end
  defp handle_in("message", _message, socket) do
    # message from other llms, maybe we want to add that to our state? idk
    {:noreply, socket}
  end

  @impl true
  def handle_info({:socket_push, opcode, msg}, socket) do
    message = msg |> socket.serializer.decode!([opcode: :text])
    IO.inspect(message, label: "LlmClient handle_info :socket_push")

    {:noreply, socket} = handle_in(message.event, message.payload, socket)

    {:noreply, socket}
  end
  # If our owner dies, shutdown
  def handle_info({:DOWN, _ref, :process, pid, reason}, %{from_channel_pid: pid} = state) do
    IO.puts("Creating channel ended")
    {:stop, reason, state}
  end
  def handle_info(stuff, state) do
    IO.inspect(stuff, label: "405 Llmclient handle_info")
    {:noreply, state}
  end
  # def handle_info({:DOWN, _ref, :process, pid, reason}, ) do
  #   IO.inspect(pid, label: "306")
  #   IO.inspect(socket, label: "307 ----------")
  #   {:stop, reason, socket}
  # end

  @impl true

  def handle_cast({:participants, _}, state) do
    {:noreply, state}
  end
  # OS old
  # llm -> room
  def handle_cast({:broadcast, {:message, message}}, socket) do
    IO.puts("307 LlmClient {:broadcast, {:message")
    GenServer.cast(socket.assigns.room_pid, {
      :broadcast,
      {:message, message},
      socket.assigns.channel_pid # Don't send back to ourselfs
    })
    {:noreply, socket}
  end
  def handle_cast({:broadcast, {:delta, message}}, socket) do
    GenServer.cast(socket.assigns.room_pid, {
      :broadcast,
      {:delta, message},
      socket.assigns.channel_pid # Don't send back to ourselfs
    })
    {:noreply, socket}
  end

  # llm -> room
  def handle_cast({:broadcast, message}, socket) do
    GenServer.cast(socket.assigns.room_pid, {
      :broadcast,
      {:message, message},
      socket.assigns.channel_pid # Don't send back to ourselfs
    })
    {:noreply, socket}
  end
  # OE old


  @impl true
  def handle_call(:channel_pid, _from_pid, state) do

    {:reply, {self(), %{}}, state}
  end

end
