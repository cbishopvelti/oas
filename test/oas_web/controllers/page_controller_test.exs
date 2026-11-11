defmodule OasWeb.PageControllerTest do
  use OasWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Home"
  end

  test "GET / names the society", %{conn: conn} do
    {:ok, _} = Oas.Settings.update_config(%{name: "Sjef Aerial Club"}, [:name])
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "This is Sjef Aerial Club's authentication server."
  end
end
