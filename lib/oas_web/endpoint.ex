defmodule OasWeb.Endpoint do
  use Absinthe.Phoenix.Endpoint
  use Phoenix.Endpoint, otp_app: :oas

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  # Domain is read at runtime (see session_options/0) so one release can
  # serve any society's domain. Key, salt and http_only must not change or
  # every existing session is invalidated.
  @session_options [
    store: :cookie,
    key: "oas_key",
    signing_salt: "gM7uiSTx",
    http_only: false
  ]

  def signing_salt, do: @session_options[:signing_salt]

  @doc "The cookie domain from runtime config (`config :oas, OasWeb.Endpoint, domain: ...`)."
  def cookie_domain, do: Application.get_env(:oas, __MODULE__)[:domain]

  @doc "Session options with the runtime cookie domain. Used by Plug.Session and the /live socket."
  def session_options, do: Keyword.put(@session_options, :domain, cookie_domain())

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: {__MODULE__, :session_options, []}]]
  socket "/socket", OasWeb.UserSocket, longpoll: false
  socket "/public_socket", OasWeb.PublicSocket, longpoll: false
    # websocket: [connect_info: [session: @session_options]]


  plug Corsica, max_age: 600, origins: "*", expose_headers: ~w(X-Foo), allow_headers: ["content-type"]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :oas,
    gzip: false,
    only: ~w(assets fonts images favicon.ico acroyoga_logo.ico robots.txt)


  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :oas
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  # plug Absinthe.Plug,
  #   schema: OasWeb.Schema



  plug Plug.MethodOverride
  plug Plug.Head
  plug :session
  plug OasWeb.Router

  # Plug.Session with options built from runtime config. The initialised
  # options are cached in :persistent_term, keyed on the domain they were
  # built for, so they are rebuilt only if the configured domain changes.
  defp session(conn, _opts) do
    domain = cookie_domain()

    opts =
      case :persistent_term.get({__MODULE__, :session_opts}, nil) do
        {^domain, opts} ->
          opts

        _ ->
          opts = Plug.Session.init(session_options())
          :persistent_term.put({__MODULE__, :session_opts}, {domain, opts})
          opts
      end

    Plug.Session.call(conn, opts)
  end
end
