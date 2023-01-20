import Config

config :oas, Oas.Repo,
  database: System.get_env("DB_FILE") || "./dbs/sqlite-demo-dev.db",
  backup_database: "./dbs/sqlite-demo-backup"

  config :oas, OasWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {0, 0, 0, 0}, port: 4000],
  url: [host: "localhost", port: "443", scheme: "https"],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "***REMOVED***",
  watchers: [
    # Start the esbuild watcher by calling Esbuild.install_and_run(:default, args)
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]}
  ]

config :oas, Oas.Mailer, adapter: Swoosh.Adapters.Local

config :phoenix, :plug_init_mode, :runtime

config :oas,
  app_url: System.get_env("REACT_APP_ADMIN_URL") || "http://localhost:3999",
  public_url: System.get_env("REACT_APP_PUBLIC_URL") || "http://www.your-website.com/"