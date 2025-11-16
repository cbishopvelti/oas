defmodule Oas.Llm.LlmClient do
  use GenServer

  def my_start(topic) do
    # socket = %Phoenix.Socket{
    #   transport: :internal,
    #   endpoint: OasWeb.Endpoint,
    #   handler: Oas.Llm.InternalSocket,
    #   serializer: Phoenix.Socket.V2.JSONSerializer,
    #   transport_pid: nil,
    #   pubsub_server: Oas.PubSub,
    #   assigns: %{
    #   }
    # }
    # Oas.Llm.InternalSocket.connect()

    # # OasWeb.Channels.LlmChannel.start_link({socket, OasWeb.Channels.LlmChannel, topic})
    # result = Phoenix.Channel.Server.join(
    #   socket,
    #   OasWeb.Channels.LlmChannel,
    #   %{
    #     topic: topic,
    #     payload: %{},
    #     ref: make_ref(),
    #     join_ref: make_ref()
    #   },
    #   [
    #     assigns: %{},
    #     starter: fn (socket, from, child_spec) ->
    #       IO.inspect(child_spec, label: "103 child_spec")
    #       OasWeb.Channels.LlmChannel.start_link(
    #         child_spec.start |> elem(2) |> List.first()
    #       ) |> IO.inspect(label: "104")

    #     end
    #   ]
    # )

    ### ----------------

    GenServer.start(
      __MODULE__,
      %{
        topic: topic
      }
    )

    :ok
  end

  @impl true
  def init(init_args) do
    IO.puts("400 -------------------- SHOULD HAPPEN")
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
        }
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
    socket = GenServer.call(pid, :socket) # Adds joined: true
    {:ok, socket}
  end

  def handle_info({:socket_push, opcode, msg}, socket) do
    msg |> socket.serializer.decode!([opcode: :text])
    # |> IO.inspect(label: "705.2")
    {:noreply, socket}
  end


end
