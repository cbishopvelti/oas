defmodule Oas.RepoConcurrencyTest do
  @moduledoc """
  Two saves at once must queue, not fail with SQLite "database is locked".

  Saves read before they write inside one database transaction. With SQLite's
  default (deferred) transactions both saves take a read snapshot, then the
  second to write fails: its snapshot is stale once the first commits, and
  waiting doesn't help. `default_transaction_mode: :immediate` (config.exs)
  takes the write lock at BEGIN, so the second save waits for the first.

  Runs against its own database file and connection pool, outside the test
  sandbox, with the repo's real config.
  """
  use ExUnit.Case, async: false

  setup do
    path = Path.join(System.tmp_dir!(), "oas-repo-concurrency-#{System.os_time()}.db")
    on_exit(fn -> for suffix <- ["", "-wal", "-shm"], do: File.rm(path <> suffix) end)

    repo =
      start_supervised!(
        {Oas.Repo, name: nil, database: path, pool: DBConnection.ConnectionPool, pool_size: 2}
      )

    Oas.Repo.put_dynamic_repo(repo)
    Oas.Repo.query!("CREATE TABLE counters (id INTEGER PRIMARY KEY, n INTEGER NOT NULL)")
    Oas.Repo.query!("INSERT INTO counters (id, n) VALUES (1, 0)")

    %{repo: repo}
  end

  test "the repo starts transactions in immediate mode" do
    assert Oas.Repo.config()[:default_transaction_mode] == :immediate
  end

  test "two read-then-write transactions both commit", %{repo: repo} do
    parent = self()

    # Reads the counter, tells the test it has read, waits to be told to
    # write, then writes the counter it read plus one.
    save = fn name ->
      Task.async(fn ->
        Oas.Repo.put_dynamic_repo(repo)

        Oas.Repo.transact(fn ->
          %{rows: [[n]]} = Oas.Repo.query!("SELECT n FROM counters WHERE id = 1")
          send(parent, {:read, name})

          receive do
            :write -> :ok
          end

          Oas.Repo.query!("UPDATE counters SET n = ? WHERE id = 1", [n + 1])
          {:ok, n}
        end)
      end)
    end

    first = save.(:first)
    assert_receive {:read, :first}, 1_000

    second = save.(:second)
    # Deferred: the second save reads now, from the same snapshot as the
    # first. Immediate: it waits at BEGIN until the first commits.
    second_read_early =
      receive do
        {:read, :second} -> true
      after
        200 -> false
      end

    send(first.pid, :write)
    first_result = Task.await(first, 5_000)

    unless second_read_early, do: assert_receive({:read, :second}, 5_000)
    send(second.pid, :write)
    second_result = Task.await(second, 10_000)

    assert {:ok, 0} = first_result
    assert {:ok, 1} = second_result
    assert %{rows: [[2]]} = Oas.Repo.query!("SELECT n FROM counters WHERE id = 1")
  end
end
