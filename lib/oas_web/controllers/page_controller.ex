defmodule OasWeb.PageController do
  use OasWeb, :controller

  def index(conn, _params) do

    render(conn, "index.html", %{app_url: Application.fetch_env!(:oas, :app_url)})
  end
end
