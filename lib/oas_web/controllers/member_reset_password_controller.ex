defmodule OasWeb.MemberResetPasswordController do
  use OasWeb, :controller

  alias Oas.Members

  plug :get_member_by_reset_password_token when action in [:edit, :edit_login_redirect, :update]

  def new(conn, _params) do
    render(conn, "new.html")
  end

  def create(conn, %{"member" => %{"email" => email}}) do
    if member = Members.get_member_by_email(email) do
      # DEBUG ONLY, uncomment
      Members.deliver_member_reset_password_instructions(
        member,
        &Routes.member_reset_password_url(conn, :edit, &1)
      )
    end

    conn
    |> put_flash(
      :info,
      "If your email is in our system, you will receive instructions to reset your password shortly."
    )
    |> redirect(to: "/")
  end

  def edit(conn, _params) do
    render(conn, "edit.html", changeset: Members.change_member_password(conn.assigns.member))
  end

  def edit_login_redirect(conn, _prams) do
    # Write redirect cookie
    conn |> Plug.Conn.put_resp_cookie(OasWeb.CallbackPathPlug.callback_path_cookie(), %{
      callback_path: "/bookings", # TODO change to
      callback_domain: "public_url"
    }, OasWeb.CallbackPathPlug.callback_path_options())
    |> render(
      "edit.html",
      changeset: Members.change_member_password(conn.assigns.member)
    )
  end

  # Do not log in the member after reset password to avoid a
  # leaked token giving the member access to the account.
  def update(conn, %{"member" => member_params}) do
    case Members.reset_member_password(conn.assigns.member, member_params) do
      {:ok, inserted_member} ->
        case {
          Plug.Conn.fetch_cookies(conn, signed: OasWeb.CallbackPathPlug.callback_path_cookie())
          |> Map.get(:cookies)
          |> Map.get(OasWeb.CallbackPathPlug.callback_path_cookie()),
          inserted_member
        } do
          {%{
            callback_path: _callback_path,
            callback_domain: _callback_domain
          }, member} ->
            # login
            OasWeb.MemberAuth.log_in_member(
              conn,
              member,
              member_params
              |> Map.put("remember_me", "true")
            )
          _ ->
            conn
            |> put_flash(:info, "Password reset successfully.")
            |> redirect(to: Routes.member_session_path(conn, :new))
        end


      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  defp get_member_by_reset_password_token(conn, _opts) do
    %{"token" => token} = conn.params

    if member = Members.get_member_by_reset_password_token(token) do
      conn |> assign(:member, member) |> assign(:token, token)
    else
      conn
      |> put_flash(:error, "Reset password link is invalid or it has expired.")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
