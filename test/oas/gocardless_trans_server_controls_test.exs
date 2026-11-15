defmodule Oas.GocardlessTransServerControlsTest do
  # A non-200 response or a crash during a sync must not stop the GoCardless
  # import. Admins can also run a sync now, and restart the import if it stopped.
  use Oas.DataCase
  import Mock

  alias Oas.Gocardless.TransServer

  @status_query """
  query {
    gocardless_trans_status { running stopped next_run failed_on last_error stopped_reason }
  }
  """

  setup do
    Application.put_env(:oas, :gocardless_retry_ms, 300)

    Oas.Repo.get!(Oas.Config.Config, 1)
    |> Ecto.Changeset.cast(
      %{gocardless_id: "id", gocardless_key: "key", gocardless_account_id: "account"},
      [:gocardless_id, :gocardless_key, :gocardless_account_id]
    )
    |> Oas.Repo.update!()

    on_exit(fn ->
      Application.delete_env(:oas, :gocardless_retry_ms)
      Application.delete_env(:oas, :gocardless_max_failures)
      # Don't leave a server running that uses the mocks or the sandbox.
      Supervisor.terminate_child(Oas.Supervisor, Oas.Gocardless.Supervisor)
    end)

    :ok
  end

  defp gocardless_mock do
    {Oas.Gocardless, [:passthrough],
     [get_access_token: fn -> {:ok, %{access_token: "token", access_expires: 86400}} end]}
  end

  defp run(query, admin \\ true) do
    Absinthe.run(query, OasWeb.Schema, context: %{current_member: %{is_admin: admin, is_reviewer: false}})
  end

  test "a 503 from GoCardless is logged and retried instead of stopping the server" do
    with_mocks([
      gocardless_mock(),
      {:hackney, [:passthrough],
       [
         request: fn _method, _url, _headers -> {:ok, 503, [], make_ref()} end,
         body: fn _ref -> {:ok, ~s({"detail": "Service unavailable"})} end
       ]}
    ]) do
      Oas.Gocardless.Supervisor.restart()
      :timer.sleep(150)

      assert TransServer.alive?()
      status = TransServer.status()
      assert status.last_error =~ "HTTP 503"
      assert status.failed_on != nil
      assert is_integer(status.next_in)

      assert {:ok, %{data: %{"gocardless_trans_status" => gql_status}}} = run(@status_query)
      assert gql_status["stopped"] == false
      assert gql_status["last_error"] =~ "Service unavailable"

      # Tried again after retry_ms
      :timer.sleep(400)
      assert TransServer.alive?()
      assert :meck.num_calls(:hackney, :request, :_) >= 2
    end
  end

  test "stops after too many failures in a row, and says why" do
    Application.put_env(:oas, :gocardless_max_failures, 2)

    with_mocks([
      gocardless_mock(),
      {Oas.Gocardless.Transactions, [],
       [process_transacitons: fn -> {:error, "HTTP 503: down"} end]}
    ]) do
      Oas.Gocardless.Supervisor.restart()
      :timer.sleep(150)
      assert TransServer.alive?()

      # Second failure, after retry_ms, stops it
      :timer.sleep(400)
      refute TransServer.alive?()
      assert_called_exactly(Oas.Gocardless.Transactions.process_transacitons(), 2)

      assert {:ok, %{data: %{"gocardless_trans_status" => status}}} = run(@status_query)
      assert status["stopped"] == true
      assert status["stopped_reason"] =~ "after 2 failed imports in a row: HTTP 503: down"
    end
  end

  test "an exception during a sync is caught and the server keeps running" do
    with_mocks([
      gocardless_mock(),
      {Oas.Gocardless.Transactions, [],
       [process_transacitons: fn -> raise "boom" end]}
    ]) do
      Oas.Gocardless.Supervisor.restart()
      :timer.sleep(150)

      assert TransServer.alive?()
      assert TransServer.status().last_error =~ "boom"
    end
  end

  test "run now syncs straight away, restart brings a stopped server back" do
    with_mocks([
      gocardless_mock(),
      {Oas.Gocardless.Transactions, [],
       [process_transacitons: fn -> {:ok, []} end]}
    ]) do
      Oas.Gocardless.Supervisor.restart()
      :timer.sleep(150)
      assert_called_exactly(Oas.Gocardless.Transactions.process_transacitons(), 1)

      assert {:ok, %{data: %{"gocardless_trans_run_now" => %{"success" => true}}}} =
               run("mutation { gocardless_trans_run_now { success } }")
      :timer.sleep(150)
      assert_called_exactly(Oas.Gocardless.Transactions.process_transacitons(), 2)
      assert TransServer.status().last_error == nil

      # Restarting a running server is refused
      assert {:ok, %{errors: [%{message: "The GoCardless import is already running"}]}} =
               run("mutation { gocardless_trans_restart { success } }")

      # Stop it the way a crash would leave it
      Supervisor.terminate_child(Oas.Gocardless.Supervisor, TransServer)
      refute TransServer.alive?()

      assert {:ok, %{data: %{"gocardless_trans_status" => %{"stopped" => true}}}} = run(@status_query)
      assert {:ok, %{errors: [_]}} = run("mutation { gocardless_trans_run_now { success } }")

      assert {:ok, %{data: %{"gocardless_trans_restart" => %{"success" => true}}}} =
               run("mutation { gocardless_trans_restart { success } }")
      assert TransServer.alive?()
      :timer.sleep(150)
      assert_called_exactly(Oas.Gocardless.Transactions.process_transacitons(), 3)
    end
  end

  test "only admins can restart or run now" do
    for mutation <- ["gocardless_trans_restart", "gocardless_trans_run_now"] do
      assert {:ok, %{errors: [%{message: message}]}} =
               run("mutation { #{mutation} { success } }", false)
      assert message =~ "403"
    end
  end
end
