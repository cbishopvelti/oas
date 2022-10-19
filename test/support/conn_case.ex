defmodule OasWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use OasWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import OasWeb.ConnCase

      alias OasWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint OasWeb.Endpoint
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Oas.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that registers and logs in members.

      setup :register_and_log_in_member

  It stores an updated connection and a registered member in the
  test context.
  """
  def register_and_log_in_member(%{conn: conn}) do
    member = Oas.MembersFixtures.member_fixture()
    %{conn: log_in_member(conn, member), member: member}
  end

  @doc """
  Logs the given `member` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_member(conn, member) do
    token = Oas.Members.generate_member_session_token(member)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:member_token, token)
  end
end
