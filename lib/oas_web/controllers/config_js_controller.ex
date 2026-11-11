defmodule OasWeb.ConfigJsController do
  @moduledoc """
  Serves `/api/config.js`, which sets `window.OAS_CONFIG` so the admin and
  public front ends can read their URLs from the server at run time instead
  of having them baked in at build time.
  """
  use OasWeb, :controller

  def show(conn, _params) do
    config = %{
      serverUrl: OasWeb.Endpoint.url(),
      adminUrl: Application.fetch_env!(:oas, :app_url),
      publicUrl: Application.fetch_env!(:oas, :public_url)
    }

    conn
    |> put_resp_content_type("application/javascript")
    |> put_resp_header("cache-control", "no-store")
    |> send_resp(200, "window.OAS_CONFIG = #{Jason.encode!(config, escape: :javascript_safe)};\n")
  end
end
