defmodule Oas.Llm.LangChainLlm do
  alias LangChain.Message.ContentPart
  alias LangChain.Message
  alias LangChain.ChatModels.ChatOpenAI
  alias LangChain.Utils.ChainResult
  alias LangChain.Chains.LLMChain

  use GenServer

  def start_link(parent_pid) do
    GenServer.start_link(__MODULE__, %{
      parent_pid: parent_pid
    })
  end

  @impl true
  def init(state) do
    callbacks = %{
      on_llm_new_delta: fn _model, deltas ->
        # IO.inspect("001", label: "305 deltas")
        Enum.each(deltas, fn delta ->
          IO.write(delta.content)
          GenServer.cast(state.parent_pid, {:broadcast, {:delta, %{
            content: delta.content,
            role: delta.role,
            status: delta.status
          }}})
        end)

      end,
      on_message_processed: fn _chain, %Message{} = data ->
        IO.inspect(data, label: "306 data")

        # GenServer.cast(self(), {:broadcast, message: %{
        #   content: data.content.content,
        #   role: data.role,
        #   status: data.status
        # }})
      end
    }

    chain = LLMChain.new!(%{
      llm: ChatOpenAI.new!(%{
        endpoint: "http://localhost:1234/v1/chat/completions",
        # model: "qwen/qwen3-4b-2507",
        model: "qwen/qwen3-8b",
        stream: true
      })
    })
    |> LLMChain.add_callback(callbacks)
    |> LLMChain.add_tools(Oas.Llm.Tools.get_tools())

    {:ok,
      state |> Map.put(:chain, chain)
    }
  end # init


  @impl true
  def handle_cast({:prompt, message}, state) do
    {:ok, chain} = state.chain
    |> LLMChain.add_message(
      message
    )
    |> LLMChain.run(mode: :while_needs_response)

    {:noreply, %{ state | chain: chain }}
  end

end
