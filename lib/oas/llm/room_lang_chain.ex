defmodule Oas.Llm.RoomLangChain do
  alias LangChain.Message.ContentPart
  alias LangChain.Message
  alias LangChain.ChatModels.ChatOpenAI
  alias LangChain.Utils.ChainResult
  alias LangChain.Chains.LLMChain
  use GenServer

  def start(topic, {pid, id_str}) do
    name = {:via, Registry, {OasWeb.Channels.LlmRegistry, topic}}
    out = case GenServer.start(__MODULE__, %{
      parents: Map.new([{pid, id_str}])
    }, name: name) do
      {:ok, pid} ->
        {:ok, pid}
      {:error, {:already_started, pid_of_existing_process}} ->
        send(pid_of_existing_process, {:add_parent, {pid, id_str}})
        # Process.monitor(pid_of_existing_process)
        {:ok, pid_of_existing_process}
      other -> other
    end

    out
  end

  @impl true
  def init(state) do
    # State is typically any Elixir term, here it's an integer (the count).
    state.parents |> Enum.map(fn {pid, _} ->
      Process.monitor(pid)
    end)

    # callbacks = %{
    #   on_llm_new_delta: fn _model, deltas ->
    #     # IO.inspect("001", label: "305 deltas")
    #     Enum.each(deltas, fn delta ->
    #       IO.write(delta.content)
    #       GenServer.cast(self(), {:broadcast, {:delta, %{
    #         content: delta.content,
    #         role: delta.role,
    #         status: delta.status
    #       }}})
    #     end)

    #   end,
    #   on_message_processed: fn _chain, %Message{} = data ->
    #     IO.inspect(data, label: "306 data")

    #     # GenServer.cast(self(), {:broadcast, message: %{
    #     #   content: data.content.content,
    #     #   role: data.role,
    #     #   status: data.status
    #     # }})
    #   end
    # }

    # chain = LLMChain.new!(%{
    #   llm: ChatOpenAI.new!(%{
    #     endpoint: "http://localhost:1234/v1/chat/completions",
    #     # model: "qwen/qwen3-4b-2507",
    #     model: "qwen/qwen3-8b",
    #     stream: true
    #   })
    # })
    # |> LLMChain.add_callback(callbacks)
    # |> LLMChain.add_tools(Oas.Llm.Tools.get_tools())
    {:ok, chain_pid} = Oas.Llm.LangChainLlm.start_link(self())

    {
      :ok,
    # state
    #   |> Map.put(:chain, chain)
      state |> Map.put(:chain_pid, chain_pid)
    }
  end

  @impl true
  def handle_info({:add_parent, {pid, id_str}}, state) do
    Process.monitor(pid)
    # TODO: Send state of chain to new client.
    # state_for_js = state.chain.messages |> Enum.map(fn message ->
    #   message_to_js(message)
    # end)

    messages_for_js = GenServer.call(state.chain_pid, :get_messages)


    GenServer.cast(pid, {:state, messages_for_js})

    # IO.inspect(state.chain, label: "001 handle_info :add_parent")
    {:noreply, %{state | parents: Map.put(state.parents, pid, id_str)}}
  end
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    new_parents = Map.delete(state.parents, pid)

    # Shutdown the thing if there are no connected channels
    if Map.size(new_parents) === 0 do
      IO.puts("Last monitor is gone. Shutting down worker.")
      {:stop, :normal, %{state | parents: new_parents}}
    else
      # Continue running
      {:noreply, %{state | parents: new_parents}}
    end
  end
  def handle_info(msg, state) do
    IO.inspect(msg, label: "205 handle_info msg")
    {:noreply, state}
  end


  @impl true
  # client -> llm
  def handle_cast({:prompt, prompt, {pid, who_id_str}}, state) do
    IO.puts("handle_cast :prompt")

    message = Message.new_user!(prompt)
    |> Map.put(:metadata, %{
      who_id_str: who_id_str
    })

    GenServer.cast(self(), {:broadcast, {:prompt, Oas.Llm.LangChainLlm.message_to_js(message)}, pid})

    # {:ok, chain} = state.chain
    # |> LLMChain.add_message(
    #   message
    # )
    # |> LLMChain.run(mode: :while_needs_response)
    GenServer.cast(state.chain_pid, {:prompt, message})

    # {:noreply, ChainResult.to_string!(chain)}
    {:noreply, state}
  end
  # llm -> client
  def handle_cast({:broadcast, message, not_pid}, state) do
    parents = state.parents |> Map.delete(not_pid)
    Enum.each(parents, fn {pid, _id_str} ->
      GenServer.cast(pid, message)
    end)
    {:noreply, state}
  end
  def handle_cast({:broadcast, message}, state) do
    Enum.each(state.parents, fn {pid, _id_str} ->
      GenServer.cast(pid, message)
    end)

    {:noreply, state}
  end
end
