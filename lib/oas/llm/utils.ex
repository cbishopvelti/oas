defmodule Oas.Llm.Utils do
  alias LangChain.Utils
  alias LangChain.Message.ContentPart
  alias LangChain.Message
  alias LangChain.Chains.LLMChain

  defp decode(item, opts \\ [])
  defp decode(item, opts) when is_list(item) do
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
  defp decode(item, opts) when is_map(item) do
    Enum.map(item, fn ({k, v}) ->
      key = String.to_atom(k)
      case key do
        :content ->
          {key, decode(v, struct: ContentPart)}
        :status -> {key , decode(v) |> String.to_atom()}
        :role -> {key, decode(v) |> String.to_atom()}
        :type -> {key, decode(v) |> String.to_atom()}
        key ->
          {key, decode(v)}
      end
    end)
    |> Map.new()

  end
  defp decode(item, _opts) do
    item
  end
  def restore(%{chat: nil}) do
    []
  end
  def restore(%{chat: chat}) do
    Jason.decode!(chat)["messages"]
    |> decode(struct: Message)
  end

  def save(state) do
    json_chat = JSON.encode!(
      Utils.to_serializable_map(
        struct(LLMChain, state |> Map.take([:messages])),
        [:messages]
      )
    )

    out = state.chat
    |> Ecto.Changeset.cast(
      %{chat: json_chat},
      [:chat]
    )
    |> Oas.Repo.update!(returning: true)

    out
  end
end
