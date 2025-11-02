defmodule OasWeb.Channels.LlmChannel do
  alias LangChain.Utils.ChainResult
  alias LangChain.Function
  alias LangChain.Message
  alias LangChain.ChatModels.ChatOpenAI
  alias LangChain.Chains.LLMChain
  use Phoenix.Channel

  def join("llm:" <> _private_room_id, _params, socket) do
    IO.puts("001 LlmChannel pid: #{inspect(self())}")

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

    IO.inspect(who_id_str, label: "101.1 who_id_str")

    metas = %{
      online_at: System.system_time(:second),
    } |> then(fn metas ->
      if current_member = socket.assigns[:current_member] do
        member_data =
          current_member
          |> Map.from_struct()
          |> Map.take([:id, :email, :name, :is_admin, :is_reviewer])

        Map.put(metas, :current_member, member_data)
      else
        metas
      end
    end)



    {:ok, _} = OasWeb.Channels.LlmChannelPresence.track(socket, who_id_str, metas)

    # register llm
    # name = {:via, Registry, {OasWeb.Channels.LlmRegistry, socket.topic}}
    # {:ok, pid} = OasWeb.Channels.LlmGenServer.start(socket.topic, self())
    {:ok, pid } = Oas.Llm.RoomLangChain.start(socket.topic, self())

    push(socket, "presence_state", OasWeb.Channels.LlmChannelPresence.list(socket))

    Process.monitor(pid)

    {:noreply, Phoenix.Socket.assign(socket, llm_gen_server: pid)}
  end
  def handle_info({:DOWN, _ref, :process, pid, reason}, %{assigns: %{llm_gen_server: pid}} = state) do
    IO.puts("LlmChannel :DOWN #{_ref}, #{pid}, #{reason}")
    {:stop, reason, state}
  end

  # Data from the llm
  def handle_cast({:data, data}, socket) do
    IO.inspect(data, label: "007 handle_cast SHOULD HAPPEN")
    push(socket, "data", data)
    {:noreply, socket}
  end
  def handle_cast(_stuff, socket) do
    IO.inspect(socket, label: "008 WAT handle_cast SHOULDN'T HAPPEN")
    {:noreply, socket}
  end

  def handle_in("prompt", prompt, socket) do
    GenServer.cast(socket.assigns[:llm_gen_server], {:prompt, prompt, get_who_id_str(socket)})
    {:noreply, socket}
  end
  def handle_in("who_am_i", _, socket) do
    # IO.inspect(socket.assigns, label: "006 socket.assigns")
    metas = %{
      who_id_str: get_who_id_str(socket),
    } |> then(fn metas ->
      if current_member = socket.assigns[:current_member] do
        member_data =
          current_member
          |> Map.from_struct()
          |> Map.take([:id, :email, :name, :is_admin, :is_reviewer])
        Map.put(metas, :current_member, member_data)
      else
        metas
      end
    end)

    {:reply, {:ok, metas}, socket}
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

    IO.inspect(result, label: "001 result")
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

    IO.inspect(chain, label: "001 chain")
    IO.inspect(ChainResult.to_string!(chain), label: "102 to_string(chain)")
  end
end
