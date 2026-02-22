defmodule Oas.BackupJob do
  use GenServer

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(state) do
    schedule()

    {:ok, state}
  end

  def handle_info(:backup, state) do
    # the actual work to be done
    IO.puts("Running backup ...")

    # work is done, let's schedule again
    Oas.Repo.backup()

    IO.puts("EO Running backup")

    {:noreply, state}
  end

  defp schedule() do
    # schedule after one minute
    # Process.send_after(self(), :backup, 120_000)
    :timer.send_interval(86_400_000, :backup)
  end
end
