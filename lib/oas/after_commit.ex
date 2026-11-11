defmodule Oas.AfterCommit do
  @moduledoc """
  Runs side effects (emails, subscription publishes) only once the database
  write they belong to has been committed, so nothing is sent for a write that
  rolls back.

  Code that writes in a transaction calls `run/1` *after* its own
  `Oas.Repo.transact/1` has returned `{:ok, _}`:

      case Oas.Repo.transact(fn -> ... end) do
        {:ok, result} ->
          Oas.AfterCommit.run(fn -> publish(result) end)
          {:ok, result}
        error ->
          error
      end

  On its own that runs the function straight away. When the caller is itself
  running inside an outer `Oas.AfterCommit.transact/1`, its "commit" is not
  final yet, so the function is held back and only runs once the outer
  transaction commits. If the outer transaction rolls back or raises, the held
  functions are dropped.

  Use `transact/1` instead of `Oas.Repo.transact/1` for any transaction that
  wraps code which calls `run/1` (for example a loop over
  `Oas.Attendance.add_attendance/2`). An outer plain `Oas.Repo.transact/1`
  does not hold anything back.
  """

  @key {__MODULE__, :queue}

  @doc """
  Like `Oas.Repo.transact/2`, and afterwards runs the functions queued with
  `run/1` inside it, in order, if and only if it committed.
  """
  def transact(fun, opts \\ []) do
    case Process.get(@key) do
      nil ->
        Process.put(@key, [])

        {result, queued} =
          try do
            {Oas.Repo.transact(fun, opts), Process.get(@key, [])}
          after
            Process.delete(@key)
          end

        case result do
          {:ok, _} -> queued |> Enum.reverse() |> Enum.each(& &1.())
          _ -> :ok
        end

        result

      _queue ->
        # Nested: the outermost transact/1 runs the queue.
        Oas.Repo.transact(fun, opts)
    end
  end

  @doc """
  Runs `fun` now, or once the surrounding `transact/1` commits. Returns `:ok`.
  """
  def run(fun) when is_function(fun, 0) do
    case Process.get(@key) do
      nil -> fun.()
      queue -> Process.put(@key, [fun | queue])
    end

    :ok
  end
end
