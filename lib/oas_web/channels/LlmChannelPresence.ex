defmodule OasWeb.Channels.LlmChannelPresence do
  use Phoenix.Presence,
    otp_app: :oas,
    pubsub_server: Oas.PubSub

  def init(_opts) do
    {:ok, %{}}
  end

  # def handle_metas(topic, %{joins: joins, leaves: leaves}, presences, state) do

  #   IO.puts("001 handle_metas, topic: #{topic}")
  #   IO.inspect(joins, label: "001.1 joins")
  #   IO.inspect(leaves, label: "001.2 leaves")
  #   IO.inspect(presences, label: "001.3 presences")
  #   IO.inspect(state, label: "001.4 state")

  #   messages = (get_in(joins, ["messages", :metas]) || [])
  #   |> Enum.map(fn %{who: who, message: message} -> %{role: "user", content: "message"} end)

  #   IO.inspect(state, label: "001.5 messages")

  #   {:ok, %{
  #     messages: messages
  #   }}
  # end
end
