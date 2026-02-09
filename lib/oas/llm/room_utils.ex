import Ecto.Query, only: [from: 2]

defmodule Oas.Llm.RoomUtils do

  def notify_someone(message, state) do
    members_to_notify = state.chat.members
    |> Enum.filter(fn %{id: id} -> id != message.metadata |> get_in([:member, :id]) end)

    {members_to_notify, send_admins} = case members_to_notify do
      [] -> # The user is the only person in the room so send to admins
        {from(m in Oas.Members.Member,
        where: m.is_admin == ^true)
        |> Oas.Repo.all(), true}
      members -> # Send to other participants
        {members, false}
    end

    # Everyone in the room
    presence = OasWeb.Channels.LlmChannelPresence.list(state.topic)
    |> Map.to_list()
    |> Enum.flat_map(fn {_id, %{metas: metas}} ->
      Enum.map(metas, fn %{member: member} -> member.id end)
    end)
    |> MapSet.new()

    presence # Mark as seen, as they're in the room currently
    |> Enum.map(fn member_id ->
      now = DateTime.utc_now() |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)
      %{
        member_id: member_id,
        chat_id: state.chat.id,
        updated_at: now,
        inserted_at: now
      }
    end)
    |> (&(Oas.Repo.insert_all(Oas.Llm.ChatSeen, &1, on_conflict: {:replace, [:updated_at]}))).()
    |> dbg()

    presence_x_sender = presence |> MapSet.reject(fn id -> id == (message.metadata |> get_in([:member, :id])) end)

    members_to_notify_ids = members_to_notify
    |> Enum.filter(fn member -> !MapSet.member?(presence, member.id) end)
    |> Enum.map(fn %{id: id} -> id end)
    |> MapSet.new()

    if presence_x_sender |> MapSet.size() > 0 and send_admins do

    else
      OasWeb.Channels.LlmChannelPresence.list("global")
      |> Map.to_list()
      |> Enum.flat_map(fn {_id, %{metas: metas}} ->
        Enum.map(metas, fn meta -> meta end)
      end)
      |> Enum.filter(fn
        %{member: nil} -> false # they're anonymous
        %{member: member} ->
          MapSet.member?(members_to_notify_ids, member.id)
      end)
      |> Enum.each(fn meta ->
        send(meta.from_channel_pid, {:new_message, %{
          topic: state.topic,
          presence_name: message.metadata.presence_name
        }})
      end)
    end

    :ok
  end

end
