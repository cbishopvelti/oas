import Ecto.Query, only: [from: 2]

defmodule OasWeb.Channels.LlmHistoryChannel do
  use Phoenix.Channel

  def join("history", _params, socket) do
    IO.puts("LlmHistory join")
    send(self(), :after_join)
    # OasWeb.Endpoint.subscribe("history")

    {:ok, socket}
  end

  def handle_info(:after_join, socket) do
    history =
      case socket.assigns do
        %{current_member: %{is_admin: true}} ->
          members =
            from(m in Oas.Members.Member,
              select: [:id, :name]
            )

          history =
            from(c in Oas.Llm.Chat,
              preload: [members: ^members],
              where: true,
              order_by: [desc: :updated_at],
              # DEBUG ONLY, set higher
              limit: 1256
            )
            |> Oas.Repo.all()

          push(socket, "history", %{
            history: history
          })

          # IO.inspect(OasWeb.Channels.LlmChannelPresence.list(history |> List.first() |> Map.get(:topic)), label: "103.1 presence list")
          history

        %{current_member: current_member} ->
          members =
            from(m in Oas.Members.Member,
              select: [:id, :name]
            )

          history =
            from(c in Oas.Llm.Chat,
              preload: [members: ^members],
              join: m2 in assoc(c, :members),
              select: c,
              where: m2.id == ^current_member.id,
              order_by: [desc: :updated_at],
              limit: 1256
              # limit: 2  # DEBUG ONLY, set higher
            )
            |> Oas.Repo.all()

          push(socket, "history", %{
            history: history
          })

          history

        # No history for anonymous
        %{} ->
          []
      end

    case history do
      [] ->
        nil

      history ->
        presence =
          history
          |> Enum.map(fn history ->
            topic = history |> Map.get(:topic)

            OasWeb.Channels.LlmChannelPresence.list(topic)
            |> OasWeb.Channels.LlmChannelPresence.add_topic(topic)
          end)
          |> Enum.reduce(&Map.merge/2)

        push(
          socket,
          "presence_state",
          presence
        )
    end

    {:noreply, socket |> assign(:history, history)}
  end

  def handle_info(msg, socket) do
    IO.inspect(msg, label: "101 handle_info")
    {:noreply, socket}
  end

  # def handle_cast(:new_history, new_history, socket) do
  #   broadcast(socket, "new_history", new_history)

  #   {:noreply, socket}
  # end

  # OasWeb.Endpoint.broadcast!("history", "new_message", %{wat: "wat"})
  intercept ["new_history", "llm_presence_diff"]

  def handle_out("new_history", new_history_item, socket) do
    IO.puts("105 new_history")

    case !is_nil(socket.assigns.current_member.is_admin) and
           socket.assigns.current_member.is_admin do
      true ->
        push(socket, "new_history", new_history_item)

        old_history_index =
          socket.assigns.history
          |> Enum.find_index(fn %{id: id} ->
            id == new_history_item.id
          end)

        new_history =
          if old_history_index != nil do
            socket.assigns.history |> List.delete_at(old_history_index)
          else
            socket.assigns.history
          end

        new_history = [new_history_item | new_history]

        {:noreply, assign(socket, :history, new_history)}

      false ->
        if new_history_item.members
           |> Enum.any?(fn %{id: id} -> id == socket.assigns.current_member.id end) do
          push(socket, "new_history", new_history_item)

          old_history_index =
            socket.assigns.history
            |> Enum.find_index(fn %{id: id} ->
              id == new_history_item.id
            end)

          new_history =
            if old_history_index != nil do
              socket.assigns.history |> List.delete_at(old_history_index)
            else
              socket.assigns.history
            end

          new_history = [new_history_item | new_history]

          {:noreply, assign(socket, :history, new_history)}
        else
          {:noreply, socket}
        end
    end
  end

  def handle_out("llm_presence_diff", %{joins: joins, leaves: leaves}, socket) do
    topics = socket.assigns.history |> Enum.map(fn %{topic: topic} -> topic end) |> MapSet.new()

    push(socket, "presence_diff", %{
      joins:
        joins
        |> Map.filter(fn {_k, v} ->
          MapSet.member?(topics, v.topic)
        end),
      leaves:
        leaves
        |> Map.filter(fn {_k, v} ->
          MapSet.member?(topics, v.topic)
        end)
    })

    {:noreply, socket}
  end
end
