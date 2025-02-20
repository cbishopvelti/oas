import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :oas, Oas.Repo,
  database: System.get_env("DB_FILE") || "./dbs/sqlite-2023-test.db",
  # username: "postgres",
  # password: "postgres",
  # hostname: "localhost",
  # database: "oas_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :oas, OasWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "***REMOVED***",
  server: false

# In test we don't send emails.
config :oas, Oas.Mailer, adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :oas,
  app_url: "http://localhost:3999",
  public_url: System.get_env("REACT_APP_PUBLIC_URL") || "http://localhost:3998"
