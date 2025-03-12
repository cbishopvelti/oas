defmodule OasWeb.Context do
  @behaviour Plug

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    newConn = OasWeb.MemberAuth.fetch_current_member(conn, %{});

    %{assigns: %{current_member: currentMember}} = newConn

    out = case currentMember do
      %{is_admin: true, is_active: true} -> Absinthe.Plug.put_options(newConn, %{context: %{
        current_member: currentMember,
        logout_link: OasWeb.Router.Helpers.member_session_path(newConn, :delete),
        conn: newConn,
        user_table: :user_table
      }})
      %{is_reviewer: true, is_active: true} -> Absinthe.Plug.put_options(newConn, %{context: %{
          current_member: currentMember,
          logout_link: OasWeb.Router.Helpers.member_session_path(newConn, :delete),
          conn: newConn
        }})
      %{is_active: true} -> Absinthe.Plug.put_options(newConn, %{context: %{
        current_member: currentMember,
        logout_link: OasWeb.Router.Helpers.member_session_path(newConn, :delete),
        conn: newConn
      }})
      # _ -> Plug.Conn.send_resp(conn, :unauthorized, "Unauthorized")
      _ -> Absinthe.Plug.put_options(newConn, %{context: %{
        conn: conn
      }})
    end

    out
  end
end
