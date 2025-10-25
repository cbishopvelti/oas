defmodule OasWeb.Channels.LlmChannel do
  use Phoenix.Channel

  def join("llm:" <> _private_room_id, _params, socket) do

    IO.puts("001 LlmChannel pid: #{inspect(self())}")
    # new_socket = if (!socket.assigns[:client]) do
    #   client = Ollama.init()
    #   # Map.put(socket.assigns, :client, client)
    #   new_socket = Phoenix.Socket.assign(socket, client: client)
    #   {:ok, response} = Ollama.chat(client,
    #     model: "qwen3:0.6b",
    #     stream: true,
    #     messages: [
    #       %{role: "system", content: "You are a helpfull acrobat assistent. Say hi."}
    #     ]
    #   )
    #   new_socket = Phoenix
    #   new_socket
    # else
    #   socket
    # end

    send(self(), :after_join)



    {
      :ok,
      Phoenix.Socket.assign(socket, %{who_id_str: get_who_id_str(socket)})
    }
  end

  def handle_info(:after_join, socket) do
    # Register genserver
    IO.inspect(socket.assigns, label: "101 member")

    who_id_str = get_who_id_str(socket)

    {:ok, _} = OasWeb.Channels.LlmChannelPresence.track(socket, who_id_str, %{
      online_at: inspect(System.system_time(:second))
    })

    # register llm
    # name = {:via, Registry, {OasWeb.Channels.LlmRegistry, socket.topic}}
    {:ok, pid} = OasWeb.Channels.LlmGenServer.start(socket.topic, self())
    Process.monitor(pid)

    {:noreply, Phoenix.Socket.assign(socket, llm_gen_server: pid)}
  end
  def handle_info({:DOWN, _ref, :process, pid, reason}, %{assigns: %{llm_gen_server: pid}} = state) do
    {:stop, reason, state}
  end

  # Data from the llm
  def handle_cast({:data, data}, socket) do
    IO.inspect(data, label: "007 handle_cast SHOULD HAPPEN")
    push(socket, "data", data)
    {:noreply, socket}
  end
  def handle_cast(stuff, socket) do
    IO.inspect(socket, label: "008 WAT handle_cast SHOULDN'T HAPPEN")
    {:noreply, socket}
  end

  def handle_in("prompt", prompt, socket) do
    # broadcast!(socket, "echo", %{
    #   echo: prompt
    # })
    GenServer.cast(socket.assigns[:llm_gen_server], {:prompt, prompt, get_who_id_str(socket)})
    {:noreply, socket}
  end
  def handle_in("who_am_i", _, socket) do
    IO.inspect(socket.assigns, label: "006 socket.assigns")
    {:reply, {:ok, %{
      current_member: socket.assigns[:current_member],
      who_id_str: socket.assigns[:who_id_str]
    }}, socket}
  end

  defp get_who_id_str(socket) do
    who_id = with current_member when is_map(current_member) <- Map.get(socket.assigns, :current_member),
      id when id != nil <- Map.get(current_member, :id)
    do
      id |> to_string()
    else
      _ -> "annonomous" <> "#{inspect(socket.channel_pid)}"
    end
    who_id
  end

  # OasWeb.Channels.LlmChannel.test_ollama_query()
  def test_ollama_query do
    client =  Ollama.init()
    result = Ollama.completion(client, [
      model: "qwen3:0.6b",
      prompt: "Why is the sky blue?"
    ])

    IO.inspect(result, label: "001 result")

  end
end
