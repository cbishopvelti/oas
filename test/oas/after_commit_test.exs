defmodule Oas.AfterCommitTest do
  use Oas.DataCase, async: false

  alias Oas.AfterCommit

  defp note(label), do: fn -> send(self(), {:ran, label, Repo.in_transaction?()}) end

  test "run/1 runs straight away outside transact/1" do
    assert :ok = AfterCommit.run(note(:a))
    assert_received {:ran, :a, false}
  end

  test "run/1 inside transact/1 waits for the commit, and keeps the order" do
    assert {:ok, :done} =
             AfterCommit.transact(fn ->
               AfterCommit.run(note(:a))
               AfterCommit.run(note(:b))
               refute_received {:ran, _, _}
               {:ok, :done}
             end)

    assert {:messages, [{:ran, :a, false}, {:ran, :b, false}]} = Process.info(self(), :messages)
  end

  test "nothing runs when the transaction returns an error" do
    assert {:error, :nope} =
             AfterCommit.transact(fn ->
               AfterCommit.run(note(:a))
               {:error, :nope}
             end)

    refute_received {:ran, _, _}
    # and nothing is left queued for the next transaction
    assert {:ok, 1} = AfterCommit.transact(fn -> {:ok, 1} end)
    refute_received {:ran, _, _}
  end

  test "nothing runs when the transaction raises" do
    assert_raise RuntimeError, "boom", fn ->
      AfterCommit.transact(fn ->
        AfterCommit.run(note(:a))
        raise "boom"
      end)
    end

    refute_received {:ran, _, _}
    assert :ok = AfterCommit.run(note(:b))
    assert_received {:ran, :b, false}
  end

  test "a nested transact/1 leaves the queue to the outermost one" do
    assert {:ok, :outer} =
             AfterCommit.transact(fn ->
               assert {:ok, :inner} =
                        AfterCommit.transact(fn ->
                          AfterCommit.run(note(:a))
                          {:ok, :inner}
                        end)

               refute_received {:ran, _, _}
               {:ok, :outer}
             end)

    assert_received {:ran, :a, false}
  end

  test "work that committed inside an outer transaction is dropped when the outer one rolls back" do
    assert {:error, :outer_failed} =
             AfterCommit.transact(fn ->
               {:ok, _} = Repo.transact(fn -> {:ok, :inner} end)
               AfterCommit.run(note(:a))
               {:error, :outer_failed}
             end)

    refute_received {:ran, _, _}
  end

  describe "a side effect that fails after the commit" do
    import ExUnit.CaptureLog

    test "run/1 outside transact/1 logs it and still returns :ok" do
      log =
        capture_log(fn ->
          assert :ok = AfterCommit.run(fn -> raise "publish is down" end)
          assert :ok = AfterCommit.run(fn -> throw(:nope) end)
          assert :ok = AfterCommit.run(fn -> exit(:gone) end)
        end)

      assert log =~ "publish is down"
      assert log =~ "side effect failed after commit"
    end

    test "transact/1 still returns its result and runs the side effects queued after it" do
      log =
        capture_log(fn ->
          assert {:ok, :done} =
                   AfterCommit.transact(fn ->
                     AfterCommit.run(note(:a))
                     AfterCommit.run(fn -> raise "publish is down" end)
                     AfterCommit.run(note(:b))
                     {:ok, :done}
                   end)
        end)

      assert log =~ "publish is down"
      assert_received {:ran, :a, false}
      assert_received {:ran, :b, false}
    end

    test "transact/1 can be used again afterwards" do
      capture_log(fn ->
        assert {:ok, :done} =
                 AfterCommit.transact(fn ->
                   AfterCommit.run(fn -> raise "publish is down" end)
                   {:ok, :done}
                 end)
      end)

      assert :ok = AfterCommit.run(note(:later))
      assert_received {:ran, :later, false}
    end
  end
end
