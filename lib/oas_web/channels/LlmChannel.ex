require Protocol
Protocol.derive(Jason.Encoder, LangChain.Message)
Protocol.derive(Jason.Encoder, LangChain.Message.ContentPart)


defmodule OasWeb.Channels.LlmChannel do
  alias LangChain.MessageDelta
  alias LangChain.Message
  alias LangChain.ChatModels.ChatOpenAI
  alias LangChain.Chains.LLMChain
  use Phoenix.Channel

  def join("llm:" <> _room_uuid, _params, socket) do
    IO.puts("001 OasWeb.Channels.LlmChannel.join pid: #{inspect(self())}")

    send(self(), :after_join)

    {
      :ok,
      Phoenix.Socket.assign(socket, %{
        presence_id: Oas.Llm.Utils.get_presence_id(socket),
        presence_name: Oas.Llm.Utils.get_presence_name(socket)
      })
    }
  end

  # Safe to push to client
  defp socket_to_member_map(socket) do

    member = if current_member = socket.assigns[:current_member] do
      member_data =
        current_member
        |> Map.from_struct()
        |> Map.take([:id, :name, :is_admin, :is_reviewer])

      member_data
    else
      nil
    end

    member
  end

  def handle_info(:after_join, socket) do
    # IO.puts("205 LlmChannel :after_join #{inspect(self())}")
    # IO.inspect(socket.assigns.current_member, label: "506 current_member")
    member = socket_to_member_map(socket)

    # Presence
    # IO.inspect(OasWeb.Channels.LlmChannelPresence.list(socket), label: "206")
    metas = %{
      channel_pid: self(),
      online_at: System.system_time(:second),
      from_channel_pid: socket.assigns[:from_channel_pid]
    } |> then(fn metas ->
      Map.put(metas, :member, member)
      |> Map.put(:presence_name, Oas.Llm.Utils.get_presence_name(socket))
      |> Map.put(:presence_id, Oas.Llm.Utils.get_presence_id(socket))
    end)

    # Room pid
    {:ok, pid } = Oas.Llm.Room.start(socket.topic, {self(), %{
    }})
    Process.monitor(pid)

    # Presence
    {:ok, _} = OasWeb.Channels.LlmChannelPresence.track(socket, Oas.Llm.Utils.get_presence_id(socket), metas)

    messages = GenServer.call(pid, :messages)
    participants = GenServer.call(pid, :participants)
    # IO.inspect(messages, label: "501 messages")
    push(socket, "messages", %{
      participants: participants |> Enum.map(fn participant ->
        participant |> Map.take([:id, :name])
      end),
      messages: messages |> Enum.map(fn (message) ->
        Oas.Llm.LangChainLlm.message_to_js(message)
      end),
      who_am_i: %{
        presence_id: Oas.Llm.Utils.get_presence_id(socket),
        presence_name: Oas.Llm.Utils.get_presence_name(socket),
        channel_pid: inspect(self())
      } |> (&(if !is_nil(socket_to_member_map(socket)), do: Map.put(&1, :member, socket_to_member_map(socket)), else: &1 )).(),
    })

    # Send presence after room initialization
    push(
      socket,
      "presence_state",
      OasWeb.Channels.LlmChannelPresence.list(socket)
    )

    {:noreply, Phoenix.Socket.assign(socket, room_pid: pid)}
  end
  def handle_info(:delta, socket) when is_nil(socket.assigns.delta) do
    {:noreply, socket}
  end
  def handle_info(:delta, socket) do
    push(socket, Atom.to_string(:delta), socket.assigns.delta |> delta_to_out())

    {:noreply,
      socket
      |> assign(:delta, nil)
      |> assign(:delta_debounce, Process.send_after(self(), :delta, 500))
    }
  end
  def handle_info({:DOWN, _ref, :process, pid, reason}, %{assigns: %{room_pid: pid}} = state) do
    # IO.puts("LlmChannel :DOWN #{_ref}, #{pid}, #{reason}")
    {:stop, reason, state}
  end

  defp delta_to_out(delta) do
    %{
      content: LangChain.MessageDelta.content_to_string(delta),
      role: delta.role,
      status: delta.status,
      metadata: delta.metadata
    }
  end

  # OasWeb.Channels.LlmChannel.test_merge()
  def test_merge() do
    MessageDelta.merge_delta(
      %LangChain.MessageDelta{
        # content: "test0",
        merged_content: [
          %LangChain.Message.ContentPart{type: :text, content: "<think>", options: []}
        ],
        status: :incomplete,
        index: 0,
        role: :assistant,
        tool_calls: nil,
        metadata: %{index: 14}
      },
      %LangChain.MessageDelta{
        content: "test1",
        # merged_content: [
        #   %LangChain.Message.ContentPart{type: :text, content: "THINK2", options: []}
        # ],
        status: :incomplete,
        index: 0,
        role: :assistant,
        tool_calls: nil,
        metadata: %{index: 14}
      }
    )
  end

  defp debounce_data({:delta, message}, socket) do
    # IO.inspect(message, label: "101 deltas message")
    new_delta = if (socket.assigns |> Map.has_key?(:delta)) && !(socket.assigns |> Map.get(:delta) |> is_nil()) do
      MessageDelta.merge_delta(
        socket.assigns |> Map.get(:delta),
        message
      )
    else
      message
    end
    # IO.inspect(message, label: "101 start")
    # IO.inspect(new_delta, label: "101.2 new_delta")

    if (message.status == :complete) do

      # IO.inspect(message, label: "102 end")
      push(socket, Atom.to_string(:delta), new_delta |> delta_to_out())

      Process.cancel_timer(socket.assigns.delta_debounce)
      socket |> assign(:delta, nil) |> assign(:delta_debounce, nil)
    else
      if ( is_nil(socket.assigns |> Map.get(:delta_debounce, nil)) || !(socket.assigns |> Map.get(:delta_debounce, nil) |> Process.read_timer())) do
        IO.puts("vvvvv START START START vvvvv")
        push(socket, Atom.to_string(:delta), new_delta |> delta_to_out())

        Phoenix.Socket.assign(socket, :delta_debounce,
          Process.send_after(self(), :delta, 20)
        ) |> assign(:delta, nil)
      else
        Phoenix.Socket.assign(socket, :delta, new_delta)
      end
    end
  end

  def handle_cast({:delta, message}, socket) do

    socket = debounce_data({:delta, message}, socket)
    {:noreply, socket}
  end
  # room -> client
  def handle_cast({:message, message}, socket) do

    push(
      socket,
      Atom.to_string(:message),
      message
    )
    {:noreply, socket}
  end
  def handle_cast({:state, messages}, socket) do
    push(
      socket,
      Atom.to_string(:state),
      %{messages: messages}
    )
    {:noreply, socket}
  end
  # Other Clients -> Client, for sending prompts from other users
  def handle_cast({:prompt, message}, socket) do
    IO.inspect(socket, label: "LlmChannel handle_cast :prompt")
    push(
      socket,
      Atom.to_string(:prompt),
      message
    )
    {:noreply, socket}
  end
  def handle_cast({:participants, participants}, socket) do
    push(
      socket,
      Atom.to_string(:participants),
      participants
    )
    {:noreply, socket}
  end
  def handle_cast(stuff, socket) do
    IO.inspect(stuff, label: "008 WAT handle_cast SHOULDN'T HAPPEN")
    {:noreply, socket}
  end

  def handle_in("prompt", prompt, socket) do

    broadcast_from!(socket, "message",
      LangChain.Message.new_user!(prompt)
      |> Map.put(:metadata, %{
        presence_id: socket.assigns.presence_id,
        presence_name: socket.assigns.presence_name,
      } |> then(fn meta ->
        case socket.assigns do
          %{current_member: current_member} ->
            meta |> Map.put(:member, current_member |> Map.take([:id]))
          _ -> meta
        end
      end)
      )
    )

    {:noreply, socket}
  end
  def handle_in("toggle_llm", %{"presence_id" => presence_id, "value" => value}, socket) when is_bitstring(presence_id) do

    case (socket.assigns |> Map.get(:current_member, %{is_admin: false })).is_admin
      or presence_id == socket.assigns |> Map.get(:presence_id)
    do
      true -> # is authed to do this
        case value do
          true ->
            # IO.inspect(socket.assigns, label: "301 socket.assigns")
            # IO.inspect(OasWeb.Channels.LlmChannelPresence.list(socket.topic), label: "302 presence")
            channel_meta = OasWeb.Channels.LlmChannelPresence.get_by_key(socket.topic, presence_id).metas
            |> List.first() # TODO
            channel_pid = channel_meta |> Map.get(:channel_pid)

            {:ok, pid} = Oas.Llm.LlmClient.start(
              socket.topic,
              {
                channel_pid,
                channel_meta
                |> Map.put(:room_pid, socket.assigns.room_pid),
              }
            )
          false ->
            my_pids = OasWeb.Channels.LlmChannelPresence.list(socket)[presence_id]
            |> Map.get(:metas)
            |> Enum.map(fn %{channel_pid: channel_pid} -> channel_pid end)


            OasWeb.Channels.LlmChannelPresence.list(socket)
            |> Map.to_list()
            |> Enum.filter(fn ({_k, %{metas: metas}}) ->
              Enum.any?(metas, fn (%{from_channel_pid: from_channel_pid}) ->
                from_channel_pid in my_pids
              end)
            end)
            |> Enum.each(fn {_k, %{metas: metas}} ->
              metas |> Enum.each(fn %{pid: pid} ->
                GenServer.stop(IEx.Helpers.pid(pid))
              end)

            end)
        end

        {:noreply, socket}
      false -> # Do nothing, not authorized
        {:noreply, socket}
    end
  end

end
