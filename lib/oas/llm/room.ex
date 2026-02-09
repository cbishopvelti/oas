import Ecto.Query, only: [from: 2]

# defmodule Oas.Llm.RoomLangChain do
defmodule Oas.Llm.Room do
  use GenServer


  defp truncate() do
    Oas.Repo.delete_all(Oas.Llm.Chat)
  end

  def start(topic, {pid, channel_context}) do
    name = {:via, Registry, {OasWeb.Channels.LlmRegistry, topic}}

    out =
      case GenServer.start(
        __MODULE__,
        %{
          parents: Map.new([{pid, channel_context}]),
          topic: topic
        },
        name: name
      ) do
        {:ok, pid} ->
          {:ok, pid}

        {:error, {:already_started, pid_of_existing_process}} ->
          # send(pid_of_existing_process, {:add_parent, {pid, channel_context}})
          # Process.monitor(pid_of_existing_process)
          {:ok, pid_of_existing_process}

        other ->
          other
      end
    out
  end


  @impl true
  def init(init_args) do
    OasWeb.Endpoint.subscribe(init_args.topic)

    init_message = LangChain.Message.new_assistant!(
      "Hi, leave a message and it will be passed to our admin team and/or our AI."
    )

    struct(LangChain.Chains.LLMChain, %{
      messages: [init_message]
    })

    messages = LangChain.Utils.to_serializable_map(
    struct(LangChain.Chains.LLMChain, %{
      messages: [init_message]
    }), [:messages])
    |> JSON.encode!()

    result = %Oas.Llm.Chat{}
    |> Ecto.Changeset.cast(%{
      topic: init_args.topic,
      chat: messages
    }, [
      :topic,
      :chat
    ])
    |> Ecto.Changeset.unique_constraint(:topic)
    |> Oas.Repo.insert(returning: true)

    {:ok, chat } = case result do
      {:ok, chat} -> # New chat
        {:ok, %{chat | members: [], seen: [] } } # Manually mark members as loaded and empty.

      {:error, %{errors: [topic: _]}} -> # Constraint error, already exists
        chat = from(c in Oas.Llm.Chat,
          preload: [:members, :seen],
          where: c.topic == ^init_args.topic
        ) |> Oas.Repo.one!() # |> (&({:ok, &1})).()
        out = chat
        |> Ecto.Changeset.change()
        |> Oas.Repo.update!(returning: true)

        {:ok, out}
    end

    state = %{
      messages: Oas.Llm.Utils.restore(chat),
      chat: chat,
      topic: init_args.topic
    }

    {:ok, state}
  end

  @impl true
  def handle_info(%{event: "presence_empty"}, state) do
    IO.puts("Shutting down room")
    {:stop, :normal, state}
  end
  def handle_info(%{event: "presence_diff", payload: %{joins: joins}}, state) do

    config = from(c in Oas.Config.ConfigLlm, where: true) |> Oas.Repo.one!()

    new_members = joins |> Enum.flat_map(fn {_k, join} ->
      join.metas
      |> Enum.filter(fn # filter out anonymous members
        %{member: member} when not(is_nil(member)) -> true
        _ -> false
      end)
      |> Enum.map(fn %{member: member} ->
        struct(Oas.Members.Member, member)
        |> Map.put(:__meta__, %Ecto.Schema.Metadata{
          state: :loaded,
          source: "members"
        })
      end)
    end)

    chat = if (new_members |> length > 0) do
      new_chat = state.chat
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc( # Only add members if they're not admins.
        :members,
        ((new_members |> Enum.filter(fn %{is_admin: is_admin } ->
          if length(state.chat.members) == 0 do
            true
          else
            !is_admin
          end
        end)) ++ state.chat.members) |> Enum.uniq_by(fn %{id: id} -> id end)
      )
      |> Oas.Repo.update!(returning: true)

      (new_members ++ state.chat.seen) # Update seen
      |> Enum.uniq_by(fn %{id: id} -> id end)
      |> Enum.map(fn member ->
        now = DateTime.utc_now() |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)
        %{
          chat_id: state.chat.id,
          member_id: member.id,
          inserted_at: now,
          updated_at: now
        }
      end)
      |> (&(Oas.Repo.insert_all(Oas.Llm.ChatSeen, &1, on_conflict: {:replace, [:updated_at]}))).()

      if ( # If first, start llm client for first person.
        OasWeb.Channels.LlmChannelPresence.list(state.topic) |> Map.to_list() |> length == 1 &&
        OasWeb.Channels.LlmChannelPresence.list(state.topic) |> Map.to_list() |> List.first() |> elem(0) == joins |> Map.to_list() |> List.first() |> elem(0) &&
        config.llm_enabled
      ) do
        meta = OasWeb.Channels.LlmChannelPresence.list(state.topic) |> Map.to_list() |> List.first() |> elem(1) |> Map.get(:metas) |> List.first()
        |> Map.put(:room_pid, self())
        Task.Supervisor.async_nolink(Oas.TaskSupervisor, fn () ->
          # Start the llm
          {:ok, pid} = Oas.Llm.LlmClient.start(
            state.topic,
            {
              meta.channel_pid,
              meta
            }
          )
          {:llm_client_async_start, pid}
        end)
      end
      # Tell the client channels about our new participants
      OasWeb.Endpoint.broadcast_from!(
        self(),
        state.topic,
        "participants",
        %{
          participants: new_chat.members |> Enum.map(fn member ->
            member |> Map.take([:id, :name])
          end)
          |> Enum.filter(fn %{inserted_at: nil} -> false # remove fake members
            _ -> true
          end)
        }
      )

      new_chat
    else
      # Start Llm client
      state.chat
    end

    {:noreply, %{state | chat: chat}}
  end
  def handle_info(%{event: "message", payload: message}, state) do

    member = message.metadata |> Kernel.get_in([:member])
    new_chat = if (!is_nil(member)) do # Ensure the messaging member is added to the members
      new_member = struct(Oas.Members.Member, member |> Map.put(:name, message.metadata.presence_name))
      |> Ecto.put_meta(state: :loaded)
      new_members = [ new_member | state.chat.members] |> Enum.uniq_by(fn %{id: id} -> id end)
      state.chat
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:members, new_members)
    else
      state.chat
    end
    state_with_maybe_changeset = Map.put(state, :chat, new_chat)

    new_state = state_with_maybe_changeset
    |> Map.put(:messages, [message | state.messages])
    |> Oas.Llm.Utils.save()

    Oas.Llm.RoomUtils.notify_someone(message, new_state)

    if (!is_nil(member)) do
      OasWeb.Endpoint.broadcast_from!(
        self(),
        state.topic,
        "participants",
        %{
          participants: new_state.chat.members |> Enum.map(fn member ->
            member |> Map.take([:id, :name])
          end)
        }
      )
    end

    {:noreply, new_state}
  end

  # Don't do anything on llm delta's
  def handle_info(%{event: "delta"}, state) do
    {:noreply, state}
  end

  # async_nolink
  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
    {:noreply, state}
  end
  # async_nolink
  def handle_info({_ref, {:llm_client_async_start, _pid}}, state) do
    {:noreply, state}
  end
  def handle_info(message, state) do
    {:noreply, state}
  end

  @impl true
  def handle_call(:messages, _pid, state) do
    {:reply, state.messages, state}
  end
  @impl true
  def handle_call(:participants, _pid, state) do
    {:reply, state.chat.members, state}
  end

end
