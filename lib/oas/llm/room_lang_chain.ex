defmodule Oas.Llm.RoomLangChain do
  alias LangChain.Utils.ChainResult
  alias LangChain.Chains.LLMChain
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

    {:ok, chain} = LLMChain.new!(%{
      llm: ChatOpenAI.new!(%{
        endpoint: "http://localhost:1234/v1/chat/completions",
        model: "qwen/qwen3-4b-2507"
      })
    })
    |> LLMChain.add_tools(Oas.Llm.Tools.get_tools())


    {:ok,
    state
      |> Map.put(:chain, chain)
    }
  end

  @impl true
  def handle_info(msg, state) do
    IO.inspect(msg, label: "205 handle_info msg")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:prompt, prompt, who_id_str}, state) do
    IO.puts("handle_cast :prompt")

    {:ok, chain} = state.chain
    |> LLMChain.add_message(prompt)


    IO.inspect(ChainResult.to_string!(chain), label: "handle_cast :prompt out")
    {:noreply, ChainResult.to_string!(chain)}
  end
end
