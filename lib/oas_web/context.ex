defmodule OasWeb.Context do
  @behaviour Plug

  import Plug.Conn
  import Ecto.Query, only: [where: 2]

  alias MyApp.{Repo, User}

  def init(opts), do: opts

  def call(conn, _) do
    newConn = OasWeb.MemberAuth.fetch_current_member(conn, %{});

    %{assigns: %{current_member: currentMember}} = newConn

    out = case currentMember do
      %{is_admin: true} -> newConn
      _ -> Plug.Conn.send_resp(conn, :unauthorized, "Unauthorized")
    end
  end
end