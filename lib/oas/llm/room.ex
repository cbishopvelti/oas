import Ecto.Query, only: [from: 2]

# defmodule Oas.Llm.RoomLangChain do
defmodule Oas.Llm.Room do
  use GenServer

  def start(topic, {pid, channel_context}) do
    name = {:via, Registry, {OasWeb.Channels.LlmRegistry, topic}}

    # IO.inspect(topic, label: "201")
    # IO.inspect(pid, label: "202")
    # IO.inspect(channel_context, label: "203")

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

    result = %Oas.Llm.Chat{}
    |> Ecto.Changeset.cast(%{
      topic: init_args.topic
    }, [:topic])
    |> Ecto.Changeset.unique_constraint(:topic)
    |> Oas.Repo.insert(returning: true)

    {:ok, chat } = case result do
      {:ok, chat} ->
        {:ok, %{chat | members: [] } } # Manually mark members as loaded and empty.
      {:error, %{errors: [topic: _]}} -> # Constraint error, already exists
        chat = from(c in Oas.Llm.Chat,
          preload: [:members],
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

    new_members = joins |> Enum.flat_map(fn {_k, join} ->
      join.metas
      |> Enum.filter(fn
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
      # IO.inspect(new_members, label: "607 new_members")
      # IO.inspect(state.chat.members, label: "670.2 old_members")
      new_chat = state.chat
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(
        :members,
        (new_members ++ state.chat.members) |> Enum.dedup_by(fn %{id: id} -> id end)
      )
      |> Oas.Repo.update!(returning: true)

      if ( # If first, start llm client for first person.
        OasWeb.Channels.LlmChannelPresence.list(state.topic) |> Map.to_list() |> length == 1 &&
        OasWeb.Channels.LlmChannelPresence.list(state.topic) |> Map.to_list() |> List.first() |> elem(0) ==
        joins |> Map.to_list() |> List.first() |> elem(0)
      ) do
        meta = OasWeb.Channels.LlmChannelPresence.list(state.topic) |> Map.to_list() |> List.first() |> elem(1) |> Map.get(:metas) |> List.first()
        |> Map.put(:room_pid, self())
        Task.Supervisor.async_nolink(Oas.TaskSupervisor, fn () ->
          # Start the llm
          {:ok, _pid} = Oas.Llm.LlmClient.start(
            state.topic,
            {
              meta.channel_pid,
              meta
            }
          )
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
        }
      )

      new_chat
    else
      # Start Llm client
      state.chat
    end

    IO.puts("608.4 :noreply")
    {:noreply, %{state | chat: chat}}
  end
  def handle_info(%{event: "message", payload: message}, state) do
    new_state = state |> Map.put(:messages, [message | state.messages])
    Oas.Llm.Utils.save(new_state)

    {:noreply, new_state}
  end

  # Don't do anything on llm delta's
  def handle_info(%{event: "delta"}, state) do
    {:noreply, state}
  end
  def handle_info(message, state) do
    IO.inspect(message, label: "601 Room.handle_info UNHANDLED MESSAGE")
    {:noreply, state}
  end

  @impl true
  def handle_call(:messages, _pid, state) do
    IO.puts("609 handle_call :messages")
    {:reply, state.messages, state}
  end
  @impl true
  def handle_call(:participants, _pid, state) do
    {:reply, state.chat.members, state}
  end


  # # ----- OLD -----

  # def init_old(init_args) do
  #   # State is typically any Elixir term, here it's an integer (the count).
  #   init_args.parents
  #   |> Enum.map(fn {pid, _} ->
  #     Process.monitor(pid)
  #   end)


  #   members_ecto = init_args.parents
  #   |> Map.to_list()
  #   |> Enum.filter(fn
  #     {_pid, %{member: nil}} ->
  #       false
  #     {_pid, %{member: member}} -> # Don't add anonnomous users
  #       member |> Map.has_key?(:id)
  #   end)
  #   |> Enum.map(fn ({_pid, %{member: member}}) ->
  #     member
  #   end)

  #   result = %Oas.Llm.Chat{}
  #   |> Ecto.Changeset.cast(%{
  #     topic: init_args.topic
  #   }, [:topic])
  #   |> Ecto.Changeset.unique_constraint(:topic)
  #   |> Ecto.Changeset.put_assoc(:members,
  #     members_ecto
  #   )
  #   |> Oas.Repo.insert(returning: true)

  #   {:ok, chat } = case result do
  #     {:ok, chat} ->
  #       {:ok, chat}
  #     {:error, %{errors: [topic: _]}} -> # Constraint error, already exists
  #       chat = from(c in Oas.Llm.Chat,
  #         preload: [:members],
  #         where: c.topic == ^init_args.topic
  #       ) |> Oas.Repo.one!() # |> (&({:ok, &1})).()
  #       out = chat
  #       |> Ecto.Changeset.change()
  #       |> Ecto.Changeset.put_assoc(
  #         :members,
  #         (members_ecto ++ chat.members) |> Enum.dedup_by(fn %{id: id} -> id end)
  #       )
  #       |> Oas.Repo.update!(returning: true)

  #       {:ok, out}
  #   end

  #   messages = Oas.Llm.Utils.restore(chat)

  #   GenServer.cast(self(), {:broadcast, { # could be a new participant
  #     :participants,
  #     %{ participants: chat.members
  #       |> Enum.map(fn member -> member |> Map.from_struct() |> Map.take([:id, :name]) end)
  #     }
  #   }})

  #   state = %{}
  #   |> Map.put(:parents, init_args.parents)
  #   |> Map.put(:messages, messages)
  #   |> Map.put(:chat, chat)
  #   |> Map.put(:topic, init_args.topic)

  #   # state = refresh_llm(state)
  #   # maybe_start_llm(state)


  #   OasWeb.Endpoint.broadcast!("history", "new_history", chat)

  #   {
  #     :ok,
  #     state
  #   }
  # end

  # def maybe_start_llm(state) do
  #   # state.parents()
  #   LlmClient.join(state.topic)
  # end

  # @deprecated "No longer used"
  # defp refresh_llm(state) do
  #   # Shut the old llm
  #   if state |> Map.has_key?(:chain_pid) do
  #     Process.unlink(state.chain_pid)
  #     Process.exit(state.chain_pid, :normal)
  #   end

  #   presence_meta = OasWeb.Channels.LlmChannelPresence.list(state.topic)
  #   |> Map.to_list()
  #   |> Enum.find_value(fn ({_pres_id, presence}) ->
  #     presence.metas |> Enum.find(fn %{llm: llm} ->
  #       llm
  #     end)
  #   end)

  #   state = if presence_meta do
  #     {:ok, chain_pid} = Oas.Llm.LangChainLlm.start_link(
  #       self(),
  #       state.messages,
  #       presence_meta.member
  #     )

  #     state |> Map.put(:chain_pid, chain_pid)
  #   else
  #     state
  #   end

  #   state
  # end

  # @impl true
  # def handle_info({:add_parent, {pid, channel_context}}, state) do
  #   Process.monitor(pid)
  #   # TODO: Send state of chain to new client.
  #   # state_for_js = state.chain.messages |> Enum.map(fn message ->
  #   #   message_to_js(message)
  #   # end)

  #   new_chat = if (
  #     channel_context |> Map.has_key?(:member) && channel_context |> Map.get(:member) |> is_map() &&
  #     channel_context.member |> Map.has_key?(:id)
  #   ) do # Only if they're not anonymous
  #     state.chat
  #     |> Ecto.Changeset.change()
  #     |> Ecto.Changeset.put_assoc(:members,
  #       [channel_context.member | state.chat.members]
  #       |> Enum.sort_by(fn (%{id: id}) -> id end)
  #       |> Enum.dedup_by(fn (%{id: id}) -> id end)
  #     )
  #     |> Oas.Repo.update!(returning: true)
  #   else
  #     state.chat
  #   end

  #   # messages_for_js = GenServer.call(state.chain_pid, :get_messages)

  #   # GenServer.cast(pid, {:state, messages_for_js}) # Send the channel current message history
  #   GenServer.cast(self(), {:broadcast, {
  #     :participants,
  #     %{
  #       participants: new_chat.members
  #       |> Enum.map(fn member -> member |> Map.from_struct() |> Map.take([:id, :name]) end)
  #     }
  #   }})

  #   # OasWeb.Endpoint.broadcast!("history", "new_history", new_chat)

  #   # IO.inspect(state.chain, label: "001 handle_info :add_parent")
  #   {:noreply, %{state | parents: Map.put(state.parents, pid, channel_context), chat: new_chat}}
  # end
  # def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
  #   new_parents = Map.delete(state.parents, pid)

  #   # Shutdown the thing if there are no connected channels
  #   if map_size(new_parents) === 0 do
  #     IO.puts("Last monitor is gone. Shutting down worker.")
  #     IO.inspect(_reason)
  #     {:stop, :normal, %{state | parents: new_parents}}
  #   else
  #     # Continue running
  #     {:noreply, %{state | parents: new_parents}}
  #   end
  # end
  # def handle_info(msg, state) do
  #   IO.inspect(msg, label: "204 SHOULD NOT HAPPEN handle_info msg")
  #   {:noreply, state}
  # end

  # # client -> llm
  # @impl true
  # def handle_cast({:prompt, prompt, {pid, member}}, state) do
  #   IO.puts("Room handle_cast :prompt")

  #   message =
  #     Message.new_user!(prompt)
  #     |> Map.put(:metadata, %{
  #       member: member,
  #       index: state.messages |> length,
  #       from_channel_pid: pid
  #     })

  #   GenServer.cast(
  #     self(),
  #     {:broadcast, {
  #       :prompt,
  #       Oas.Llm.LangChainLlm.message_to_js(message)
  #       # message
  #     }, pid}
  #   )

  #   # Only send to llm if it on for us
  #   # if (
  #   #   !!(OasWeb.Channels.LlmChannelPresence.get_by_key(state.topic, member.presence_id)
  #   #   .metas |> Enum.find(fn (%{llm: llm}) -> llm end))
  #   # ) do
  #   #   GenServer.cast(state.chain_pid, {:prompt, message})
  #   # end


  #   new_state = state |> Map.put(:messages, [ message | state.messages])
  #   new_state = Map.put(new_state, :chat, Oas.Llm.Utils.save(new_state))

  #   {:noreply,
  #     new_state
  #   }
  # end
  # def handle_cast(:refresh_llm, state) do
  #   state = refresh_llm(state)
  #   {:noreply, state}
  # end


  # def handle_cast({:boardcast, {:delta, message}, not_pid}, state) do
  #   parents = state.parents |> Map.delete(not_pid)
  #   Enum.each(parents, fn {pid, _id_str} ->
  #     GenServer.cast(pid, {:delta, message})
  #   end)

  #   {:noreply, state}
  # end
  # def handle_cast({:broadcast, {:message, message}, not_pid}, state) do
  #   IO.puts("Room {:broadcast, {:message")
  #   parents = state.parents |> Map.delete(not_pid)

  #   Enum.each(parents, fn ({pid, _id_str}) ->
  #     GenServer.cast(
  #       pid,
  #        {:message,
  #         %{
  #           content: (message.content || [])
  #             |> Enum.map(fn (item) -> %{
  #               content: item.content,
  #               type: item.type
  #             } end),
  #           role: message.role,
  #           status: message.status,
  #           metadata: message.metadata
  #         }
  #       }
  #     )
  #   end)

  #   new_state = state |> Map.put(:messages, [message | state.messages])
  #   Oas.Llm.Utils.save(new_state)

  #   {:noreply, new_state}
  # end
  # # delta
  # def handle_cast({:broadcast, message, not_pid}, state) do
  #   parents = state.parents |> Map.delete(not_pid)

  #   Enum.each(parents, fn {pid, _id_str} ->
  #     GenServer.cast(pid, message)
  #   end)

  #   {:noreply, state}
  # end
  # def handle_cast({:broadcast, message}, state) do
  #   Enum.each(state.parents, fn {pid, _id_str} ->
  #     GenServer.cast(pid, message)
  #   end)

  #   {:noreply, state}
  # end

end
