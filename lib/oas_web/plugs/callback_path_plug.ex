defmodule OasWeb.CallbackPathPlug do


  @max_age 60 * 60 # hour
  @callback_path_cookie "_oas_web_callback_path"
  @callback_path_options [sign: true, max_age: @max_age, same_site: "Strict"]

  def callback_path_cookie(), do: @callback_path_cookie

  def callback_path_plug(conn, _opts) do

    # IO.inspect(conn, label: "001")
    # IO.inspect(_opts, label: "002")
    case Map.get(conn, :query_params) do
      %{"callback_path" => callback_path, "callback_domain" => callback_domain} ->
        Plug.Conn.put_resp_cookie(conn, @callback_path_cookie, %{
          callback_path: callback_path,
          callback_domain: callback_domain || "public_url"
        }, @callback_path_options)
      _ -> conn
    end
  end

end
