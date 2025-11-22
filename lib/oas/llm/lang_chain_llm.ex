import Ecto.Query, only: [from: 2]

defmodule Oas.Llm.LangChainLlm do
  alias LangChain.MessageDelta
  alias LangChain.Message
  alias LangChain.ChatModels.ChatOpenAI
  alias LangChain.Chains.LLMChain

  use GenServer

  def start_link(parent_pid, messages, member) do
    GenServer.start_link(__MODULE__, %{
      parent_pid: parent_pid,
      messages: messages,
      member: member
    })
  end


  defp day_name(1), do: "Monday"
  defp day_name(2), do: "Tuesday"
  defp day_name(3), do: "Wednesday"
  defp day_name(4), do: "Thursday"
  defp day_name(5), do: "Friday"
  defp day_name(6), do: "Saturday"
  defp day_name(7), do: "Sunday"


  @impl true
  def init(init_args) do
    # IO.inspect(self(), label: "301 LangChainLlm init")
    callbacks = %{
      on_llm_new_delta: fn chain, deltas ->
        if ((deltas |> length) > 0) do
          GenServer.cast(
            init_args.parent_pid,
            {:broadcast_from,
              {
                "delta",
                deltas
                |> MessageDelta.merge_deltas()
                |> (&(Map.put(&1, :content, MessageDelta.content_to_string(&1)))).()
                |> Map.put(:metadata, %{
                  index: chain.messages |> length()
                })
            } }
          )
        end

      end,
      on_message_processed: fn chain, %Message{} = message ->
        # IO.inspect(message, label: "306 on_message_processed")
        # IO.inspect(1, label: "306.1 on_message_processed")
        message = message |> Map.put(
          :metadata,
          (message.metadata || %{}) |> Map.put(:index, (chain.messages |> length) - 1)
        )
        GenServer.cast(
          init_args.parent_pid,
          {:broadcast_from, {
            "message",
            message
          }}
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
            # model: "qwen/qwen3-8b",
            model: "qwen/qwen3-14b",
            stream: true
          }),
        custom_context: %{
          member: init_args.member
        }
      })
      |> LLMChain.add_message(Message.new_system!("Todays date: #{Date.utc_today()} and today is #{Date.day_of_week(Date.utc_today()) |> day_name}"))
      |> LLMChain.add_message(Message.new_system!(
        (from(cl in Oas.Config.ConfigLlm, select: cl) |> Oas.Repo.one!()).context
      ))
      |> LLMChain.add_callback(callbacks)
      |> LLMChain.add_tools(Oas.Llm.Tools.get_tools())



    chain = if (!is_nil(init_args.member) && init_args.member |> Map.has_key?(:name)) do
      LLMChain.add_message(chain, Message.new_system!("The users name is: " <> init_args.member.name))
    else
      LLMChain.add_message(chain, Message.new_system!("The user is anonymous"))
    end

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

    case state.chain
      |> LLMChain.add_message(message)
      |> LLMChain.run(mode: :while_needs_response)
    do
      {:ok, chain} ->
        {:noreply, %{state | chain: chain}}
      {:error, _chain, %{message: message, type: _type} = _error} ->
        {:stop, {:llm_error, message}, state}
      _other ->
        {:stop, :normal, state}
    end
  end
  def handle_cast({:message, message}, state) do
    chain = state.chain
    |> LLMChain.add_message(message)
    {:noreply, %{state | chain: chain}}
  end
  def handle_cast(message, state) do
    IO.inspect(message, label: "307 UNKNOWN handle_cast, message")
    {:noreply, state}
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
