defmodule OasWeb.Channels.LlmChannelPresence do
  use Phoenix.Presence,
    otp_app: :oas,
    pubsub_server: Oas.PubSub

  def init(_opts) do
    {:ok, %{}}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  def add_topic(presences, topic) do
    presences
    |> Enum.map(fn {k, v} ->
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

    OasWeb.Endpoint.broadcast("history", "llm_presence_diff", %{
      joins: joins |> add_topic(topic),
      leaves: leaves |> add_topic(topic)
    })

    {:ok, state}
  end
end
