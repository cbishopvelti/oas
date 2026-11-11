defmodule OasWeb.CookieDomainTest do
  # Not async: changes the :oas, OasWeb.Endpoint application env.
  use OasWeb.ConnCase, async: false

  import Oas.MembersFixtures

  @domain ".society.example"
  @remember_me_cookie "_oas_web_member_remember_me"

  setup do
    original = Application.get_env(:oas, OasWeb.Endpoint)
    Application.put_env(:oas, OasWeb.Endpoint, Keyword.put(original, :domain, @domain))
    on_exit(fn -> Application.put_env(:oas, OasWeb.Endpoint, original) end)

    %{member: member_fixture()}
  end

  test "session and remember-me cookies carry the runtime domain", %{conn: conn, member: member} do
    conn =
      post(conn, Routes.member_session_path(conn, :create), %{
        "member" => %{
          "email" => member.email,
          "password" => valid_member_password(),
          "remember_me" => "true"
        }
      })

    assert %{domain: @domain, http_only: false} = conn.resp_cookies["oas_key"]
    assert %{domain: @domain, same_site: "Lax"} = conn.resp_cookies[@remember_me_cookie]
  end

  test "log out deletes the remember-me cookie on the runtime domain", %{conn: conn, member: member} do
    conn = conn |> log_in_member(member) |> delete(Routes.member_session_path(conn, :delete))
    assert %{domain: @domain, max_age: 0} = conn.resp_cookies[@remember_me_cookie]
  end

  test "the /live socket session options use the runtime domain and unchanged key and salt" do
    opts = OasWeb.Endpoint.session_options()
    assert opts[:domain] == @domain
    assert opts[:key] == "oas_key"
    assert opts[:signing_salt] == "gM7uiSTx"
    assert opts[:http_only] == false
    assert OasWeb.Endpoint.signing_salt() == "gM7uiSTx"
  end
end
