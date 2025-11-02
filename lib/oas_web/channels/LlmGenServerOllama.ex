defmodule OasWeb.Channels.LlmGenServer do
  use GenServer

  def start(topic, parent_pid) do
    name = {:via, Registry, {OasWeb.Channels.LlmRegistry, topic}}
    out = case GenServer.start(__MODULE__, %{
      parents: MapSet.new([parent_pid])
    }, name: name) do
      {:ok, pid} ->
        {:ok, pid}
      {:error, {:already_started, pid_of_existing_process}} ->
        send(pid_of_existing_process, {:add_parent, parent_pid})
        # Process.monitor(pid_of_existing_process)
        {:ok, pid_of_existing_process}
      other -> other
    end

    out
  end

  @impl true
  def init(state) do
    # State is typically any Elixir term, here it's an integer (the count).
    state.parents |> Enum.map(fn pid ->
      Process.monitor(pid)
    end)

    client =  Ollama.init()

    # {:ok, chain} = LLMChain.new!(%{
    #   llm: ChatOpenAI.new!(%{
    #     endpoint: "http://localhost:1234/v1/chat/completions",
    #     model: "qwen/qwen3-4b-2507"
    #   })
    # })
    # |> LLMChain.add_tools(Oas.Llm.Tools.get_tools())


    {:ok,
    state
      |> Map.put(:client, client)
      |> Map.put(:messages, [])
    }
  end

  def handle_info({:add_parent, pid}, state) do
    Process.monitor(pid)
    {:noreply, %{state | parents: MapSet.put(state.parents, pid)}}
  end
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Remove the dead parent's PID from the list of monitors
    # This also traps Ollama.chat shutdown

    # IO.inspect(pid, label: "206.1 :DOWN")
    # IO.inspect(state.parents, label: "206.2 state.parents")

    new_parents = MapSet.delete(state.parents, pid)


    IO.puts("Monitor died: #{inspect(pid)}. Remaining: #{MapSet.size(new_parents)}")

    # Shutdown the thing if there are no connected channels
    if MapSet.size(new_parents) === 0 do
      IO.puts("Last monitor is gone. Shutting down worker.")
      {:stop, :normal, %{state | parents: new_parents}}
    else
      # Continue running
      {:noreply, %{state | parents: new_parents}}
    end
  end
  def handle_info({pid, {:data, data}}, state) do
    state.parents |>
    Enum.each(fn channel ->
      GenServer.cast(channel, {:data, data |> Map.put("pid", inspect(pid)) })
    end)

    {:noreply, state}
  end
  def handle_info({_ref, {:ok, data}}, state) do
    {
      :noreply,
      %{state | messages: state.messages ++ [%{
        content: data |> Map.get("message") |> Map.get("content"),
        role: data |> Map.get("message") |> Map.get("role")
      }]}
    }
  end
  def handle_info(msg, state) do
    IO.inspect(msg, label: "205 handle_info msg")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:prompt, prompt, who_id_str}, state) do

    IO.puts("203 handle_cast :prompt")
    new_messages = state.messages ++ [
      %{
        role: "user",
        content: prompt,
        who_id_str: who_id_str
      }
    ]

    {:ok, stream} = Ollama.chat(state.client,
      model: "qwen3:14b",
      stream: true,
      messages: [
        %{role: "system", content: "You are a helpfull acrobat assistent."}
      ] ++ new_messages |> Enum.map(fn (item) ->
        Map.take(item, [:role, :content, :images, :tool_calls])
      end)
    )

    # stream
    # |> Stream.each(fn (item) ->
    #   IO.inspect(item, label: "204 stream")
    # end)
    # |> Stream.run()

    IO.puts("===================")

    {:noreply, %{state | messages: new_messages}}
  end

end
