defmodule OasWeb.PageController do
  use OasWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
