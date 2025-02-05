import Ecto.Query, only: [from: 2]

defmodule Oas.Gocardless.Server do
  use GenServer

  # Oas.Gocardless.Server.start_link()
  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @impl true
  def init(_) do
    Process.send_after(self(), :init, 0)
    {:ok, %{}}
  end

  def handle_info(:init, state) do
    if (Map.has_key?(state, :timer_ref)) do
      Process.cancel_timer(state.timer_ref)
    end
    with {:ok, access_tokens} <- Oas.Gocardless.get_access_token(),
      %{gocardless_requisition_id: requisition_id} <- from(cc in Oas.Config.Config, select: cc) |> Oas.Repo.one
    do
      timer_ref = Process.send_after(self(), :refresh_tokens, access_tokens.access_expires)

      {:noreply, Map.merge(
        state,
        access_tokens
      )
      |> Map.put(:requisition_id, requisition_id)
      |> Map.put(:timer_ref, timer_ref)}
    else
      {:noconfig} -> {:noreply, state}
    end
  end
  def handle_info(:refresh_tokens, state) do
    access_tokens = Oas.Gocardless.refresh_access_token(state)
    Process.send_after(self(), :refresh_tokens, access_tokens.access_expires)

    {:noreply, Map.merge(
      state,
      access_tokens
    )}
  end
  def handle_info(:get_transactions, state) do
    Oas.Gocardless.get_transactions(state)
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_banks, _from, state) do
    data = Oas.Gocardless.get_banks(state)
    {:reply, data, state}
  end
  def handle_call({:get_requisitions, %{institution_id: institution_id}}, _from, state) do
    data = Oas.Gocardless.get_requisitions(state, %{institution_id: institution_id})

    new_state = state |> Map.put(:requisition_id, data["id"])
    IO.inspect(new_state, label: "009 new_state")

    {:reply, data, new_state}
  end

  def handle_call(:save_requistions, _from, state) do
    from(cc in Oas.Config.Config, select: cc)
    |> Oas.Repo.one
    |> Ecto.Changeset.cast(%{gocardless_requisition_id: state.requisition_id} , [
      :gocardless_requisition_id
    ])
    |> Oas.Repo.update

    {:reply, {}, state}
  end

  def handle_call(:get_accounts, _from, state) do
    data = Oas.Gocardless.get_accounts(state)

    {:reply, data, state}
  end

end
