defmodule OasWeb.ConfigJsControllerTest do
  use OasWeb.ConnCase

  test "GET /api/config.js serves the app URLs as JavaScript", %{conn: conn} do
    conn = get(conn, "/api/config.js")

    assert conn.status == 200
    assert [content_type] = get_resp_header(conn, "content-type")
    assert content_type =~ "application/javascript"
    assert get_resp_header(conn, "cache-control") == ["no-store"]

    assert "window.OAS_CONFIG = " <> rest = conn.resp_body
    config = rest |> String.trim_trailing() |> String.trim_trailing(";") |> Jason.decode!()

    assert config == %{
             "serverUrl" => OasWeb.Endpoint.url(),
             "adminUrl" => Application.fetch_env!(:oas, :app_url),
             "publicUrl" => Application.fetch_env!(:oas, :public_url)
           }
  end

  test "GET /api/config.js needs no login and sets no session cookie", %{conn: conn} do
    conn = get(conn, "/api/config.js")
    assert conn.status == 200
    assert conn.resp_cookies == %{}
  end
end
