defmodule Oas.Llm.Utils do
  alias LangChain.Message.ToolCall
  alias LangChain.Message.ToolResult
  alias LangChain.Utils
  alias LangChain.Message.ContentPart
  alias LangChain.Message
  alias LangChain.Chains.LLMChain

  def decode(item, opts \\ [])
  def decode(item, opts) when is_list(item) do
    struct = Keyword.get(opts, :struct)
    case struct do
      nil ->
        Enum.map(item, fn (v) ->
          decode(v)
        end)
      struct ->
        Enum.map(item, fn (v) ->
          decode(v) |> (&(Kernel.struct(struct, &1))).()
        end)
    end
  end
  def decode(item, _opts) when is_map(item) do
    Enum.map(item, fn ({k, v}) ->
      key = String.to_atom(k)
      case key do
        :content -> {key, decode(v, struct: ContentPart)}
        :tool_calls -> {key, decode(v, struct: ToolCall)}
        :tool_results -> {key, decode(v, struct: ToolResult)}
        :status -> {key , decode(v) |> String.to_atom()}
        :role -> {key, decode(v) |> String.to_atom()}
        :type -> {key, decode(v) |> String.to_atom()}
        key ->
          {key, decode(v)}
      end
    end)
    |> Map.new()

  end
  def decode(item, _opts) do
    item
  end
  def restore(%{chat: nil}) do
    []
  end
  def restore(%{chat: chat}) do

    Jason.decode!(chat)["messages"]
    # |> IO.inspect(label: "406 tool call")
    |> decode(struct: Message)
    # |> IO.inspect(label: "407")
  end

  def save(state) do
    # remove pid
    new_state = %{state | messages: state.messages |>
      Enum.map(fn (message) ->
        %{message | metadata: ((message.metadata || %{}) |> Map.drop([:from_channel_pid]))}
      end)
    }

    json_chat = JSON.encode!(
      Utils.to_serializable_map(
        struct(LLMChain, new_state |> Map.take([:messages])),
        [:messages]
      )
    )

    chat = state.chat
    |> Ecto.Changeset.cast(
      %{chat: json_chat},
      [:chat]
    )
    |> Oas.Repo.update!(returning: true)

    %{state | chat: chat}
  end

  def get_presence_id(socket) do
    case socket do
      %{assigns: %{current_member: current_member}} -> "#{current_member.id}"
      %{assigns: %{llm: llm}} -> "#{llm.name}#{inspect(llm.pid)}"
      _ -> "anonymous#{inspect(socket.channel_pid)}"
    end
  end

  def get_presence_name(socket) do
    case socket do
      %{assigns: %{current_member: current_member}} -> current_member.name
      %{assigns: %{llm: llm, from_channel_context: %{member: member}}} -> "#{llm.name} for #{member.name}"
      %{assigns: %{llm: llm}} -> "#{llm.name} for anonymous"
      _ -> "anonymous"
    end
  end
end
