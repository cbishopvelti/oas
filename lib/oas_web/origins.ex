defmodule OasWeb.Origins do
  @moduledoc """
  Decides which browser origins may call the server (CORS) and open its
  sockets (Phoenix `check_origin`).

  When `config :oas, :restrict_origins` is true, only these are allowed:

    * `:app_url` (the admin app)
    * `:public_url` (the public booking site)
    * the server's own host (`OasWeb.Endpoint` url host), for pages it serves
      itself such as LiveDashboard

  `:app_url` and `:public_url` must match on scheme, host and port. The
  server's own host matches on host only, because behind nginx the endpoint
  url's scheme and port may not be what the browser sees.

  Everything is read at call time, so the ADMIN_URL, PUBLIC_URL and PHX_HOST
  overrides in config/runtime.exs apply. When `:restrict_origins` is false
  (dev and test), every origin is allowed.
  """

  @doc "Whether origin restriction is on."
  def restricted?, do: Application.get_env(:oas, :restrict_origins, false) == true

  @doc "Corsica `{module, function, args}` callback: `conn` and origin come first."
  def cors_allowed?(_conn, origin), do: allowed?(origin)

  @doc "Phoenix `check_origin` `{module, function, args}` callback: gets the parsed URI."
  def socket_allowed?(%URI{} = uri), do: allowed?(uri)

  @doc "Whether the given origin (string or `URI`) is allowed."
  def allowed?(origin) do
    if restricted?() do
      uri = to_uri(origin)

      Enum.any?(app_origins(), &same_origin?(&1, uri)) or
        same_host?(uri.host, server_host())
    else
      true
    end
  end

  defp app_origins do
    [:app_url, :public_url]
    |> Enum.map(&Application.get_env(:oas, &1))
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&URI.parse/1)
  end

  defp server_host do
    :oas
    |> Application.get_env(OasWeb.Endpoint, [])
    |> Keyword.get(:url, [])
    |> Keyword.get(:host)
  end

  defp same_host?(a, b) when is_binary(a) and is_binary(b),
    do: String.downcase(a) == String.downcase(b)

  defp same_host?(_a, _b), do: false

  defp same_origin?(%URI{host: host} = allowed, %URI{} = actual) when is_binary(host) do
    normalise(allowed) == normalise(actual)
  end

  defp same_origin?(_allowed, _actual), do: false

  defp normalise(%URI{scheme: scheme, host: host, port: port}) do
    {scheme && String.downcase(scheme), host && String.downcase(host), port}
  end

  defp to_uri(%URI{} = uri), do: uri
  defp to_uri(origin) when is_binary(origin), do: URI.parse(origin)
  defp to_uri(_), do: %URI{}
end
