defmodule OasWeb.Channels.LlmChannelPresence do
  use Phoenix.Presence,
    otp_app: :oas,
    pubsub_server: Oas.PubSub

  def init(_opts) do
    {:ok, %{}}
  end

  def handle_info(_msg, socket) do
    # IO.inspect(msg, label: "305")
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

  def handle_metas(topic, %{joins: joins, leaves: leaves}, _presences, state) do

    # IO.puts("301 handle_metas")
    # Phoenix.PubSub.local_broadcast(.PubSub, "proxy:#{topic}", msg)
    OasWeb.Endpoint.broadcast("history", "llm_presence_diff", %{
      joins: joins |> add_topic(topic),
      leaves: leaves |> add_topic(topic)
    })
    {:ok, state}
  end
end
