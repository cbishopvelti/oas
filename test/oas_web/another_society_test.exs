defmodule OasWeb.AnotherSocietyTest do
  @moduledoc """
  Runs the server as a made-up society and checks that what the apps load
  (`/api/config.js`, the public settings query) and the pages the server draws
  (log in, landing page) show that society, with no Oxfordshire text.

  The build side of the same check is `scripts/check-no-oxfordshire.sh`.
  """
  use OasWeb.ConnCase, async: false

  @name "Lowmoor Circus Collective"
  @short_name "Lowmoor"
  @logo_url "https://cdn.lowmoor.example/logo.svg"
  @primary_color "#2a7f62"
  @admin_url "https://admin.lowmoor.example"
  @public_url "https://www.lowmoor.example"
  @log_in "/members/log_in"

  setup do
    {:ok, _} =
      Oas.Settings.update_config(
        %{
          name: @name,
          short_name: @short_name,
          logo_url: @logo_url,
          primary_color: @primary_color,
          public_site_title: @name
        },
        [:name, :short_name, :logo_url, :primary_color, :public_site_title]
      )

    for {key, value} <- [app_url: @admin_url, public_url: @public_url] do
      old = Application.fetch_env!(:oas, key)
      Application.put_env(:oas, key, value)
      on_exit(fn -> Application.put_env(:oas, key, old) end)
    end

    :ok
  end

  defp refute_oxfordshire(body) do
    refute body =~ ~r/oxfordshire/i, "found Oxfordshire in:\n#{body}"
  end

  test "/api/config.js gives the apps this society's URLs", %{conn: conn} do
    body = conn |> get("/api/config.js") |> response(200)

    assert "window.OAS_CONFIG = " <> rest = body
    config = rest |> String.trim_trailing() |> String.trim_trailing(";") |> Jason.decode!()

    assert config["adminUrl"] == @admin_url
    assert config["publicUrl"] == @public_url
    assert config["serverUrl"] == OasWeb.Endpoint.url()
    refute_oxfordshire(body)
  end

  test "the log in page shows this society's name, logo and colour", %{conn: conn} do
    body = conn |> get(@log_in) |> html_response(200)

    assert body =~ ~r/<title[^>]*>\s*#{@name}\s*<\/title>/
    assert body =~ ~s(<img src="#{@logo_url}" alt="#{@name}")
    assert body =~ ~s(<a href="#{@public_url}" class="society-logo">)
    assert body =~ "--primary-color: #{@primary_color};"
    refute_oxfordshire(body)
  end

  test "the server's landing page names this society", %{conn: conn} do
    body = conn |> get("/") |> html_response(200)

    assert body =~ @name
    refute_oxfordshire(body)
  end

  test "public_config_config gives the apps this society's branding", %{conn: conn} do
    query = """
    { public_config_config {
        name short_name logo_url primary_color public_site_title content membership_terms
    } }
    """

    body = conn |> post("/api/graphql", %{"query" => query}) |> response(200)

    assert %{"data" => %{"public_config_config" => config}} = Jason.decode!(body)

    assert %{
             "name" => @name,
             "short_name" => @short_name,
             "logo_url" => @logo_url,
             "primary_color" => @primary_color,
             "public_site_title" => @name
           } = config

    refute_oxfordshire(body)
  end
end
