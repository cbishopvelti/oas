import Ecto.Query, only: [from: 2]

defmodule Oas.Gocardless.AuthServer do
  use GenServer, restart: :transient

  # Oas.Gocardless.AuthServer.start_link()
  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @impl true
  def init(_) do
    IO.puts("Oas.Gocardless.AuthServer init")
    case Oas.Gocardless.get_access_token() do
      {:ok, access_tokens} ->
        Process.send_after(self(), :init, 0)
        {:ok, access_tokens}
      _ -> :ignore
    end
  end

  @impl true
  def handle_info(:init, state) do
    if (Map.has_key?(state, :timer_ref)) do
      Process.cancel_timer(state.timer_ref)
    end
    # with {:ok, access_tokens} <- Oas.Gocardless.get_access_token()
    with true <- true
    do
      timer_ref = Process.send_after(self(), :refresh_tokens, (state.access_expires * 1_000))

      {:noreply, Map.merge(
        state,
        %{}# access_tokens
      )
      |> Map.put(:timer_ref, timer_ref)}
    else
      {:noconfig} -> {:noreply, state}
    end
  end
  # send(Oas.Gocardless.AuthServer, :refresh_tokens)
  def handle_info(:refresh_tokens, state) do
    access_tokens = Oas.Gocardless.refresh_access_token(state)
    if (Map.has_key?(state, :timer_ref)) do
      Process.cancel_timer(state.timer_ref)
    end
    timer_ref = Process.send_after(self(), :refresh_tokens, (access_tokens.access_expires * 1_000))

    {:noreply, Map.merge(
      state,
      access_tokens
    ) |> Map.put(:timer_ref, timer_ref)}
  end

  @impl true
  def handle_call(:get_access_token, _from, %{access_token: access_token} = state) do
    {:reply, {:ok, access_token}, state}
  end
  def handle_call(:get_access_token, _from, state) do
    {:reply, {:error, :no_access_token}, state}
  end

  # Temporaly save requisition_id here until success, where it will be written to the database
  def handle_call({:get_requisitions, %{institution_id: institution_id}}, _from, state) do
    data = Oas.Gocardless.get_requisitions(state, %{institution_id: institution_id})

    new_state = state |> Map.put(:requisition_id, data["id"])

    {:reply, data, new_state}
  end

  def handle_call(:save_requisitions, _from, state) do
    from(cc in Oas.Config.Config, select: cc)
    |> Oas.Repo.one
    |> Ecto.Changeset.cast(%{gocardless_requisition_id: state.requisition_id} , [
      :gocardless_requisition_id
    ])
    |> Oas.Repo.update

    {:reply, {}, state |> Map.drop([:requisition_id])}
  end
end
