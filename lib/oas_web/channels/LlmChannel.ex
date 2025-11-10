defmodule OasWeb.Channels.LlmChannel do
  alias LangChain.Utils.ChainResult
  alias LangChain.Function
  alias LangChain.Message
  alias LangChain.ChatModels.ChatOpenAI
  alias LangChain.Chains.LLMChain
  use Phoenix.Channel

  def join("llm:" <> _private_room_id, _params, socket) do
    # IO.puts("001 LlmChannel pid: #{inspect(self())}")

    send(self(), :after_join)

    {
      :ok,
      Phoenix.Socket.assign(socket, %{
        presence_id: get_presence_id(socket)
      })
    }
  end

  defp socket_to_member_map(socket) do
    presence_id = get_presence_id(socket)

    member = if current_member = socket.assigns[:current_member] do
      member_data =
        current_member
        |> Map.from_struct()
        |> Map.take([:id, :email, :name, :is_admin, :is_reviewer])
      member_data = member_data |> Map.put(:presence_id, presence_id)

      member_data
    else
      %{
        presence_id: presence_id
      }
    end

    member
  end

  def handle_info(:after_join, socket) do
    member = socket_to_member_map(socket)

    # Presence
    metas = %{
      online_at: System.system_time(:second),
    } |> then(fn metas ->
      Map.put(metas, :member, member)
    end)
    {:ok, _} = OasWeb.Channels.LlmChannelPresence.track(socket, member.presence_id, metas)
    push(socket, "presence_state", OasWeb.Channels.LlmChannelPresence.list(socket))

    # Room pid
    {:ok, pid } = Oas.Llm.RoomLangChain.start(socket.topic, {self(), %{member: socket.assigns[:current_member]}})
    Process.monitor(pid)
    messages = GenServer.call(pid, :messages)
    push(socket, "messages", %{
      messages: messages |> Enum.map(fn (message) ->
        Oas.Llm.LangChainLlm.message_to_js(message)
      end),
      who_am_i: socket_to_member_map(socket),
    })

    {:noreply, Phoenix.Socket.assign(socket, llm_gen_server: pid)}
  end
  def handle_info({:DOWN, _ref, :process, pid, reason}, %{assigns: %{llm_gen_server: pid}} = state) do
    # IO.puts("LlmChannel :DOWN #{_ref}, #{pid}, #{reason}")
    {:stop, reason, state}
  end

  # Data from the llm
  def handle_cast({:data, data}, socket) do
    IO.inspect(data, label: "007 handle_cast :data")
    push(socket, "data", data)
    {:noreply, socket}
  end
  def handle_cast({:delta, message}, socket) do
    # IO.puts("007.2 handle_cast :delta")
    push(
      socket,
      Atom.to_string(:delta),
      message
    )
    {:noreply, socket}
  end
  def handle_cast({:message, message}, socket) do
    push(
      socket,
      Atom.to_string(:message),
      message
    )
    {:noreply, socket}
  end
  def handle_cast({:state, messages}, socket) do
    push(
      socket,
      Atom.to_string(:state),
      %{messages: messages}
    )
    {:noreply, socket}
  end
  # Client -> Client, for sending prompts from other users
  def handle_cast({:prompt, message}, socket) do
    IO.puts("handle_cast :prompt")
    push(
      socket,
      Atom.to_string(:prompt),
      message
    )
    {:noreply, socket}
  end
  def handle_cast({:participants, participants}, socket) do
    push(
      socket,
      Atom.to_string(:participants),
      participants
    )
    {:noreply, socket}
  end
  def handle_cast(_stuff, socket) do
    IO.inspect(_stuff, label: "008 WAT handle_cast SHOULDN'T HAPPEN")
    {:noreply, socket}
  end

  def handle_in("prompt", prompt, socket) do
    IO.puts("handle_in prompt")
    member = socket_to_member_map(socket)
    GenServer.cast(socket.assigns[:llm_gen_server], {:prompt, prompt, {self(), member}})
    {:noreply, socket}
  end
  def handle_in("who_am_i", _, socket) do
    # IO.inspect(socket.assigns, label: "006 socket.assigns")
    member = socket_to_member_map(socket)

    {:reply, {:ok, member}, socket}
  end
  def handle_in("messages", _, socket) do
    messages = GenServer.call(socket.assigns[:llm_gen_server], :messages)
    {:reply, {:ok, }, socket}
  end

  defp get_presence_id(socket) do
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
    # client =  Ollama.init(base_url: "http://localhost:1234/v1")
    client =  Ollama.init(base_url: "http://localhost:11434")

    result = Ollama.completion(client, [
      # model: "qwen3:0.6b",
      model: "qwen/qwen3-4b-2507",
      prompt: "Why is the sky blue?"
    ])

    # result = Ollama.chat(
    #   client,
    #   [
    #     model: "qwen/qwen3-4b-2507",
    #     messages: [
    #       %{role: "user", content: "Why is the sky blue?"}
    #     ]
    #   ]
    # )

    # IO.inspect(result, label: "001 result")
  end

  # OasWeb.Channels.LlmChannel.test_langchain()
  def test_langchain() do



    {:ok, chain} = LLMChain.new!(%{
      llm: ChatOpenAI.new!(%{
        endpoint: "http://localhost:1234/v1/chat/completions",
        model: "qwen/qwen3-4b-2507"
      })
    })
    |> LLMChain.add_message(Message.new_user!("Give me my user details."))
    |> LLMChain.run(mode: :while_needs_response)

    # IO.inspect(chain, label: "001 chain")
    IO.inspect(ChainResult.to_string!(chain), label: "102 to_string(chain)")
  end
end
