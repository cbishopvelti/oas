import Ecto.Query, only: [from: 2]

defmodule Oas.Llm.RoomLangChain do
  alias LangChain.Utils
  alias LangChain.Message.ContentPart
  alias LangChain.Message
  alias LangChain.ChatModels.ChatOpenAI
  alias LangChain.Utils.ChainResult
  alias LangChain.Chains.LLMChain
  use GenServer

  def start(topic, {pid, member}) do
    name = {:via, Registry, {OasWeb.Channels.LlmRegistry, topic}}

    out =
      case GenServer.start(
             __MODULE__,
             %{
               parents: Map.new([{pid, member}]),
               topic: topic
             },
             name: name
           ) do
        {:ok, pid} ->
          {:ok, pid}

        {:error, {:already_started, pid_of_existing_process}} ->
          send(pid_of_existing_process, {:add_parent, {pid, member}})
          # Process.monitor(pid_of_existing_process)
          {:ok, pid_of_existing_process}

        other ->
          other
      end

    out
  end

  @impl true
  def init(state) do
    # State is typically any Elixir term, here it's an integer (the count).
    state.parents
    |> Enum.map(fn {pid, _} ->
      Process.monitor(pid)
    end)

    IO.inspect(state, label: "707.1 state")

    members_ecto = state.parents
    |> Map.to_list()
    |> Enum.filter(fn {_pid, member} -> # Don't add anonnomous users
      member |> Map.has_key?(:id)
    end)
    |> Enum.map(fn ({_pid, member}) ->
      Oas.Repo.get!(Oas.Members.Member, member.id)
    end)

    result = %Oas.Llm.Chat{}
    |> Ecto.Changeset.cast(%{
      topic: state.topic
    }, [:topic])
    |> Ecto.Changeset.unique_constraint(:topic)
    |> Ecto.Changeset.put_assoc(:members,
      members_ecto
    )
    |> Oas.Repo.insert(returning: true)

    {:ok, chat } = case result do
      {:ok, chat} ->
        {:ok, chat}
      {:error, %{errors: [topic: _]}} -> # Constraint error, already exists
        chat = from(c in Oas.Llm.Chat,
          preload: [:members],
          where: c.topic == ^state.topic
        ) |> Oas.Repo.one!() # |> (&({:ok, &1})).()
        out = chat
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.put_assoc(
          :members,
          (members_ecto ++ chat.members) |> Enum.dedup_by(fn %{id: id} -> id end)
        )
        |> Oas.Repo.update!(returning: true)

        {:ok, out}
    end

    messages = Oas.Llm.Utils.restore(chat)

    # from(c in Oas.Llm.Chat,
    #   where c.topic == ^state.topic
    # ) |> Oas.Repo.

    {:ok, chain_pid} = Oas.Llm.LangChainLlm.start_link(
      self(),
      messages,
      members_ecto |> List.first() |> Map.from_struct() # TODO: Make more advanced.
    )

    {
      :ok,
      state
      |> Map.put(:chain_pid, chain_pid)
      |> Map.put(:messages, messages)
      |> Map.put(:chat, chat)
    }
  end

  @impl true
  def handle_info({:add_parent, {pid, member}}, state) do
    Process.monitor(pid)
    # TODO: Send state of chain to new client.
    # state_for_js = state.chain.messages |> Enum.map(fn message ->
    #   message_to_js(message)
    # end)

    new_chat = if (member |> Map.has_key?(:id)) do # Only if they're not annonomous
      state.chat
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:members,
        [struct(Oas.Members.Member, member) | state.chat.members]
        |> Enum.dedup_by(fn (%{id: id}) -> id end)
      )
      |> Oas.Repo.update!(returning: true)
    else
      state.chat
    end

    messages_for_js = GenServer.call(state.chain_pid, :get_messages)

    GenServer.cast(pid, {:state, messages_for_js})

    # IO.inspect(state.chain, label: "001 handle_info :add_parent")
    {:noreply, %{state | parents: Map.put(state.parents, pid, member), chat: new_chat}}
  end
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    new_parents = Map.delete(state.parents, pid)

    # Shutdown the thing if there are no connected channels
    if Map.size(new_parents) === 0 do
      IO.puts("Last monitor is gone. Shutting down worker.")
      {:stop, :normal, %{state | parents: new_parents}}
    else
      # Continue running
      {:noreply, %{state | parents: new_parents}}
    end
  end
  def handle_info(msg, state) do
    IO.inspect(msg, label: "205 SHOULD NOT HAPPEN handle_info msg")
    {:noreply, state}
  end

  # client -> llm
  @impl true
  def handle_cast({:prompt, prompt, {pid, member}}, state) do
    IO.puts("handle_cast :prompt")

    message =
      Message.new_user!(prompt)
      |> Map.put(:metadata, %{
        member: member
      })



    GenServer.cast(
      self(),
      {:broadcast, {:prompt, Oas.Llm.LangChainLlm.message_to_js(message)}, pid}
    )

    GenServer.cast(state.chain_pid, {:prompt, message})

    new_state = state |> Map.put(:messages, [ message | state.messages])
    new_state = Map.put(new_state, :chat, Oas.Llm.Utils.save(new_state))

    {:noreply,
      new_state
    }
  end

  # llm -> client
  @impl true
  def handle_cast({:message, %{message: message, message_index: message_index}}, state) do

    GenServer.cast(
      self(),
      {:broadcast,
       {:message,
        %{
          content: (message.content || [])
            |> Enum.map(fn (item) -> %{
              content: item.content,
              type: item.type
            } end),
          role: message.role,
          status: message.status,
          message_index: message_index
        }}}
    )

    new_state = state |> Map.put(:messages, [message | state.messages])
    Oas.Llm.Utils.save(new_state)

    {:noreply, new_state}
  end
  def handle_cast({:broadcast, message, not_pid}, state) do
    parents = state.parents |> Map.delete(not_pid)

    Enum.each(parents, fn {pid, _id_str} ->
      GenServer.cast(pid, message)
    end)

    {:noreply, state}
  end
  def handle_cast({:broadcast, message}, state) do
    Enum.each(state.parents, fn {pid, _id_str} ->
      GenServer.cast(pid, message)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_call(:messages, _pid, state) do
    {:reply, state.messages, state}
  end

end
