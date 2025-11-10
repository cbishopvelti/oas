defmodule Oas.Llm.LangChainLlm do
  alias LangChain.Message.ContentPart
  alias LangChain.Message
  alias LangChain.ChatModels.ChatOpenAI
  alias LangChain.Utils.ChainResult
  alias LangChain.Chains.LLMChain

  use GenServer

  def start_link(parent_pid, messages, member) do
    GenServer.start_link(__MODULE__, %{
      parent_pid: parent_pid,
      messages: messages,
      member: member
    })
  end

  @impl true
  def init(init_args) do
    callbacks = %{
      on_llm_new_delta: fn chain, deltas ->
        # IO.inspect(deltas, label: "305 on_llm_new_delta")
        Enum.each(deltas, fn delta ->
          # IO.write(delta.content)
          GenServer.cast(
            init_args.parent_pid,
            {:broadcast,
             {:delta,
              %{
                content: delta.content,
                role: delta.role,
                status: delta.status,
                message_index: chain.messages |> length()
              }}}
          )
        end)
      end,
      on_message_processed: fn chain, %Message{} = message ->
        # IO.inspect(message, label: "306 on_message_processed")
        # IO.inspect(chain, label: "306.1 chain")
        GenServer.cast(
          init_args.parent_pid,
          {:message,
            %{
              message: message,
              message_index: (chain.messages |> length()) - 1
            }
          }
        )
        nil
      end
    }

    chain =
      LLMChain.new!(%{
        llm:
          ChatOpenAI.new!(%{
            endpoint: "http://localhost:1234/v1/chat/completions",
            # model: "qwen/qwen3-4b-2507",
            model: "qwen/qwen3-8b",
            stream: true
          }),
        custom_context: %{
          member: init_args.member
        }
      })
      |> LLMChain.add_message(Message.new_system!("Todays date: #{Date.utc_today()}"))
      |> LLMChain.add_callback(callbacks)
      |> LLMChain.add_tools(Oas.Llm.Tools.get_tools())

    chain = chain |> LLMChain.add_messages(init_args.messages |> Enum.reverse())

    {:ok, %{
      parent_pid: init_args.parent_pid,
      chain: chain
    }}
  end

  # init

  def message_to_js(message) do
    %{
      content:
        case message.content do
          nil -> nil
          content -> content |> Enum.map(fn item ->
            %{
              content: item.content,
              type: item.type
            }
          end)
        end,
        # message.content
        # |> Enum.filter(fn
        #   %ContentPart{type: :text} ->
        #     true

        #   _x ->
        #     false
        # end)
        # |> Enum.map(fn %ContentPart{type: :text, content: content} ->
        #   content
        # end)
        # |> List.first(),
      # presence_id: (message.metadata || %{}) |> Map.get(:presence_id, nil),
      role: message.role,
      metadata: message.metadata
    }
  end

  @impl true
  def handle_cast({:prompt, message}, state) do
    {:ok, chain} =
      state.chain
      |> LLMChain.add_message(message)
      |> LLMChain.run(mode: :while_needs_response)

    {:noreply, %{state | chain: chain}}
  end

  @impl true
  def handle_call(:get_messages, _from, state) do
    messages_for_js =
      state.chain.messages
      |> Enum.map(fn message ->
        message_to_js(message)
      end)

    {:reply, messages_for_js, state}
  end

  def handle_call(:get_chain, _from, state) do
    {:reply, state.chain, state}
  end
end
