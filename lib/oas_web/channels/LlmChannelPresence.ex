defmodule OasWeb.Channels.LlmChannelPresence do
  use Phoenix.Presence,
    otp_app: :oas,
    pubsub_server: Oas.PubSub

  def init(_opts) do
    # IO.inspect(self(), label: "201 LlmCHannelPresence")
    {:ok, %{}}
  end

  def handle_info(_msg, socket) do
    # IO.inspect(msg, label: "205")
    {:noreply, socket}
  end

  def add_topic(presences, topic) do
    presences
    |> Enum.map(fn ({k, v}) ->
      {
        topic <> ":" <> k,
        v
        |> Map.put(:topic, topic)
        |> Map.put(:presence_id, k)
      }
    end)
    |> Map.new()
  end

  def handle_metas(topic, %{joins: joins, leaves: leaves}, presences, state) do

    if presences |> Enum.empty?() do
      OasWeb.Endpoint.broadcast!(topic, "presence_empty", nil)
    end

    # IO.puts("201 handle_metas")
    # Phoenix.PubSub.local_broadcast(.PubSub, "proxy:#{topic}", msg)
    OasWeb.Endpoint.broadcast("history", "llm_presence_diff", %{
      joins: joins |> add_topic(topic),
      leaves: leaves |> add_topic(topic)
    })
    {:ok, state}
  end
end
