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
    {:ok, pid} = OasWeb.Channels.LlmChannel.start_link({OasWeb.Endpoint, from})


    send(
      pid,
      {
        Phoenix.Channel,
        %{},
        from,
        socket # Socket needs a __channel__
      }
    )
    mon_ref = Process.monitor(pid)
    receive do
      {^ref, {:ok, reply}} ->
        Process.demonitor(mon_ref, [:flush])
        {:ok, reply, pid}

      {^ref, {:error, reply}} ->
        Process.demonitor(mon_ref, [:flush])
        {:error, reply}

      {:DOWN, ^mon_ref, _, _, reason} ->
        Logger.error(fn -> Exception.format_exit(reason) end)
        {:error, %{reason: "join crashed"}}
    end
    socket = GenServer.call(pid, :socket) # Added joined: true

    # EO Setting up channel

    # Task.async(fn () ->
    #   Process.sleep(6000)
    #   # GenServer.cast(pid, {:send_prompt, {}})
    #   push_to_in({"test_in", %{"test1" => "test2"}}, socket)
    #   {:ok, :wat}
    # end)




    {:ok, socket}
  end

  def handle_info({:socket_push, opcode, msg}, socket) do
    msg |> socket.serializer.decode!([opcode: :text])
    {:noreply, socket}
  end
  # If our owner dies, shutdown
  def handle_info({:DOWN, _ref, :process, pid, reason}, %{assigns: %{from_channel_pid: pid}} = state) do
    IO.puts("Creating channel ended")
    {:stop, reason, state}
  end
  # def handle_info({:DOWN, _ref, :process, pid, reason}, ) do
  #   IO.inspect(pid, label: "306")
  #   IO.inspect(socket, label: "307 ----------")
  #   {:stop, reason, socket}
  # end


end
