import Config

config :oas, Oas.Repo,
  username: "postgres",
  password: "pd6k",
  database: "oas",
  endpoints: [
    {"172.28.0.11", 5433}, # Node 1
    {"172.28.0.13", 5433},  # Node 3
    {"172.28.0.12", 5433} # Node 2
  ],
  backup_database: "/sqlite-backup",
  migration_lock: nil,
  log: false,
  connect_timeout: 1_000,
  timeout: 10_000,
  queue_target: 60_000


config :oas, Oas.Repo.Replica1,
  database: System.get_env("DB_FILE_REPLICA_1") || "./dbs/sqlite-dev-replica-1.db"

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with esbuild to bundle .js and .css sources.
config :oas, OasWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  domain: ".oas.local",
  http: [ip: {0, 0, 0, 0}, port: 4000],
  url: [host: "phoenix-n1.oas.local", port: 4000, scheme: "http"],
  pubsub_server: Oas.PubSub,
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "***REMOVED***",
  watchers: [
    # Start the esbuild watcher by calling Esbuild.install_and_run(:default, args)
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]}
  ]

config :oas, Oas.Mailer, adapter: Swoosh.Adapters.Local
config :oas, Oas.TokenMailer, adapter: Swoosh.Adapters.Local,
  from: {"OAS", "chris@oxfordshireacrosociety.co.uk"}

# Watch static and templates for browser reloading.
config :oas, OasWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/oas_web/(live|views)/.*(ex)$",
      ~r"lib/oas_web/templates/.*(eex)$"
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n", level: :debug,
  truncate: :infinity


# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :oas,
  app_url: System.get_env("REACT_APP_ADMIN_URL") || "http://localhost:3999",
  public_url: System.get_env("REACT_APP_PUBLIC_URL") || "http://localhost:3998",
  disable_gocardless: true,
  gocardless_backup_dir: "/gocardless_backup",
  llm_sudio_url: "http://localhost:1234/v1/chat/completions",
  vip: "172.29.0.20"
