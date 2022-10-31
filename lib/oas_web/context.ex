defmodule OasWeb.Context do
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, b) do
    newConn = OasWeb.MemberAuth.fetch_current_member(conn, %{});

    %{assigns: %{current_member: currentMember}} = newConn


    out = case currentMember do
      %{is_reviewer: true, is_active: true} -> Absinthe.Plug.put_options(newConn, %{context: %{
          current_member: currentMember,
          logout_link: OasWeb.Router.Helpers.member_session_path(newConn, :delete)
        }})
      %{is_admin: true, is_active: true} -> Absinthe.Plug.put_options(newConn, %{context: %{
        current_member: currentMember,
        logout_link: OasWeb.Router.Helpers.member_session_path(newConn, :delete)
      }})
      # _ -> Plug.Conn.send_resp(conn, :unauthorized, "Unauthorized")
      _ -> newConn
    end

    out
  end
end