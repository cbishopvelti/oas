require Protocol
Protocol.derive(Jason.Encoder, LangChain.MessageDelta)

defmodule Oas.Llm.LlmClient do
  alias Oas.Llm.LangChainLlm
  use GenServer

  def start(topic, {from_channel_pid, channel_context}) do
    {:ok, pid} =
      GenServer.start(
        __MODULE__,
        %{
          topic: topic,
          from_channel_pid: from_channel_pid,
          from_channel_context: channel_context
        }
      )

    {:ok, pid}
  end

  def push_to_in({event, payload}, socket) do
    send(
      socket.channel_pid,
      %Phoenix.Socket.Message{
        topic: socket.topic,
        event: event,
        ref: nil,
        payload: payload
      }
    )
  end

  @impl true
  def init(init_args) do
    Process.flag(:trap_exit, true)
    Process.monitor(init_args.from_channel_pid)

    state = %{
      topic: init_args.topic,
      llm: %{
        pid: self(),
        name: "assistent"
      },
      from_channel_pid: init_args.from_channel_pid,
      from_channel_context: init_args.from_channel_context
    }

    state = state |> Map.put(:presence_id, Oas.Llm.Utils.get_presence_id(%{assigns: state}))
    state = state |> Map.put(:presence_name, Oas.Llm.Utils.get_presence_name(%{assigns: state}))

    {:ok, lang_chain_llm_pid} =
      LangChainLlm.start_link(
        self(),
        # Get messages from the room
        init_args.from_channel_context.room_pid |> GenServer.call(:messages),
        init_args.from_channel_context.member
      )

    state = state |> Map.put(:lang_chain_llm_pid, lang_chain_llm_pid)

    OasWeb.Endpoint.subscribe(init_args.topic)

    OasWeb.Channels.LlmChannelPresence.track(self(), init_args.topic, state.presence_id, %{
      pid: inspect(self()),
      online_at: System.system_time(:second),
      from_channel_pid: state.from_channel_pid,
      presence_name: state.presence_name
    })

    {:ok, state}
  end

  # If our owner dies, shutdown
  @impl true
  def handle_info(
        %{event: "message", payload: %{metadata: %{presence_id: presence_id}} = message},
        %{from_channel_context: %{presence_id: presence_id}} = state
      ) do
    GenServer.cast(state.lang_chain_llm_pid, {:prompt, message})
    {:noreply, state}
  end

  def handle_info(%{event: "message", payload: message} = _broadcast, state) do
    GenServer.cast(state.lang_chain_llm_pid, {:message, message})
    {:noreply, state}
  end

  def handle_info(:delta, %{delta: delta} = state) do
    delta = pre_delta_send(delta, state)

    OasWeb.Endpoint.broadcast_from!(self(), state.topic, "delta", delta)

    {:noreply,
     state
     |> Map.delete(:delta)
     |> Map.put(:delta_debounce, Process.send_after(self(), :delta, 334))}
  end

  # Nothing to send
  def handle_info(:delta, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, %{from_channel_pid: pid} = state) do
    IO.puts("LlmClient :DOWN from_channel_pid")
    {:stop, reason, state}
  end

  def handle_info(%{event: "presence_diff"}, state) do
    {:noreply, state}
  end

  def handle_info({:EXIT, pid, reason}, %{lang_chain_llm_pid: pid} = state) do
    # IO.inspect(reason, label: "407 LlmClient :EXIT lang_chain_llm_pid SHOULD HAPPEN")

    OasWeb.Endpoint.broadcast_from!(
      self(),
      state.topic,
      "message",
      LangChain.Message.new_assistant!(
        "I have errored with: #{reason |> elem(1)}. Shutting down."
      )
      |> Map.put(:metadata, %{
        presence_id: Oas.Llm.Utils.get_presence_id(%{assigns: state}),
        presence_name: Oas.Llm.Utils.get_presence_name(%{assigns: state})
      })
    )

    {:stop, :normal, state}
  end

  def handle_info(stuff, state) do
    IO.inspect(stuff, label: "405 LlmClient handle_info UNHANDLED")
    {:noreply, state}
  end

  @impl true
  # llm -> other channels
  def handle_cast({:broadcast_from, {"delta", message}}, state) do
    presence_id = Oas.Llm.Utils.get_presence_id(%{assigns: state})
    presence_name = Oas.Llm.Utils.get_presence_name(%{assigns: state})

    message = %{
      message
      | metadata:
          message.metadata
          |> Map.put(:presence_name, presence_name)
          |> Map.put(:presence_id, presence_id)
    }

    # OasWeb.Endpoint.broadcast_from!(
    #   self(),
    #   state.topic,
    #   "delta",
    #   message
    # )
    state = debounce_data({:delta, message}, state)

    {:noreply, state}
  end

  def handle_cast({:broadcast_from, {event, message}}, state) do
    presence_id = Oas.Llm.Utils.get_presence_id(%{assigns: state})
    presence_name = Oas.Llm.Utils.get_presence_name(%{assigns: state})

    message = %{
      message
      | metadata:
          message.metadata
          |> Map.put(:presence_name, presence_name)
          |> Map.put(:presence_id, presence_id)
    }

    OasWeb.Endpoint.broadcast_from!(
      self(),
      state.topic,
      event,
      message
    )

    {:noreply, state}
  end

  def handle_cast(message, state) do
    IO.inspect(message, label: "409 unhandled message")
    {:noreply, state}
  end

  @impl true
  def handle_call(:channel_pid, _from_pid, state) do
    {:reply, {self(), %{}}, state}
  end

  defp pre_delta_send(delta, state) do
    presence_id = Oas.Llm.Utils.get_presence_id(%{assigns: state})
    presence_name = Oas.Llm.Utils.get_presence_name(%{assigns: state})

    delta = %{
      delta
      | metadata:
          delta.metadata
          |> Map.put(:presence_name, presence_name)
          |> Map.put(:presence_id, presence_id),
        content: LangChain.Message.ContentPart.content_to_string(delta.merged_content)
    }

    delta
  end

  defp debounce_data({:delta, message}, state) do
    new_delta =
      if state |> Map.has_key?(:delta) && !(state |> Map.get(:delta) |> is_nil()) do
        LangChain.MessageDelta.merge_delta(
          state |> Map.get(:delta),
          message
        )
      else
        message
      end

    cond do
      # Last delta, so send immediatly
      message.status == :complete ->
        OasWeb.Endpoint.broadcast_from!(
          self(),
          state.topic,
          "delta",
          pre_delta_send(new_delta, state)
        )

        Process.cancel_timer(state.delta_debounce)
        state |> Map.delete(:delta) |> Map.delete(:delta_debounce)

      # First delta, so send immediatly
      is_nil(state |> Map.get(:delta_debounce)) || !(state.delta_debounce |> Process.read_timer()) ->
        state
        |> Map.put(
          :delta_debounce,
          Process.send_after(self(), :delta, 60)
        )
        |> Map.put(:delta, new_delta)

      # it will be set later
      true ->
        state |> Map.put(:delta, new_delta)
    end
  end
end
