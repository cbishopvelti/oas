import OasWeb.Channels.Utils
import Ecto.Query, only: [from: 2]

defmodule OasWeb.Channels.LlmGlobalChannel do
  use Phoenix.Channel

  def join("global", _params, socket) do
    member = socket_to_member_map(socket)

    metas =
      %{
        channel_pid: self(),
        online_at: System.system_time(:second),
        from_channel_pid: self()
      }
      |> then(fn metas ->
        Map.put(metas, :member, member)
        |> Map.put(:presence_name, Oas.Llm.Utils.get_presence_name(socket))
        |> Map.put(:presence_id, Oas.Llm.Utils.get_presence_id(socket))
      end)

    OasWeb.Channels.LlmChannelPresence.track(socket, Oas.Llm.Utils.get_presence_id(socket), metas)
    send(self(), :after_join)

    {:ok,
     Phoenix.Socket.assign(socket, %{
       presence_id: Oas.Llm.Utils.get_presence_id(socket),
       presence_name: Oas.Llm.Utils.get_presence_name(socket)
     })}
  end

  def handle_info(:after_join, socket) do
    # Send unread chats
    case socket.assigns |> Map.get(:current_member) do
      # they're anonymous, so no notifications
      nil ->
        :ok

      # They're an admin, so get all single chats I haven't seen
      %{is_admin: true} = member ->
        seen_query = from(s in Oas.Llm.ChatSeen, where: s.member_id == ^member.id)

        # 2. Count of members per chat
        member_count_query =
          from(mj in Oas.Llm.ChatMembers,
            group_by: mj.chat_id,
            select: %{chat_id: mj.chat_id, count: count(mj.member_id)}
          )

        unread =
          from(c in Oas.Llm.Chat,
            left_join: s in subquery(seen_query),
            on: s.chat_id == c.id,
            left_join: mc in subquery(member_count_query),
            on: mc.chat_id == c.id,
            join: mj in assoc(c, :chat_members),
            join: m in assoc(mj, :member),
            preload: [:chat_seen, members: m],
            where: true,
            # Only one member or we're in the chat
            # We've not seen it
            # We've seen it, but it was old
            # The last message wasn't us
            where:
              (coalesce(mc.count, 0) == 1 or m.id == ^member.id) and
                (is_nil(s.id) or
                   (s.member_id == ^member.id and s.updated_at < c.updated_at and
                      fragment(
                        "coalesce(json_extract(?, '$.messages[0].metadata.member.id'), -1)",
                        c.chat
                      ) != ^member.id)),
            order_by: [desc: c.updated_at, asc: mj.id]
          )
          |> Oas.Repo.all()
          |> Enum.map(fn %{topic: topic, chat: _chat, members: members} ->
            first_member_not_us =
              members |> Enum.drop_while(fn %{id: id} -> id == member.id end) |> List.first() ||
                %{
                  name: "Alone/Anonymous"
                }

            %{
              topic: topic,
              presence_name: first_member_not_us |> Map.get(:name)
            }
          end)

        push(socket, "new_messages", %{new_messages: unread})

        :ok

      # normal member
      member ->
        unread =
          from(c in Oas.Llm.Chat,
            left_join: s in assoc(c, :chat_seen),
            join: mj in assoc(c, :chat_members),
            join: m in assoc(mj, :member),
            preload: [:chat_seen, members: m],
            where:
              m.id == ^member.id and
                (is_nil(s.id) or
                   (s.member_id == ^member.id and
                      s.updated_at < c.updated_at and
                      fragment("json_extract(?, '$.messages[0].metadata.member.id')", c.chat) !=
                        ^member.id)),
            order_by: [desc: c.updated_at, asc: mj.id]
          )
          |> Oas.Repo.all()
          |> Enum.map(fn %{topic: topic, chat: chat, members: members} ->
            first_member_not_us =
              members |> Enum.drop_while(fn %{id: id} -> id == member.id end) |> List.first() ||
                %{
                  name: "Alone"
                }

            %{
              topic: topic,
              presence_name: first_member_not_us |> Map.get(:name)
            }
          end)

        push(socket, "new_messages", %{new_messages: unread})
        :ok
    end

    {:noreply, socket}
  end

  # From server to client
  def handle_info({:new_message, payload}, socket) do
    push(socket, "new_message", payload)
    {:noreply, socket}
  end
end
