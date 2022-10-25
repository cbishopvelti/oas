# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :oas,
  ecto_repos: [Oas.Repo]

# Configures the endpoint
config :oas, OasWeb.Endpoint,
  url: [host: "0.0.0.0"],
  domain: System.get_env("DOMAIN") || "localhost",
  check_origine: false,
  render_errors: [view: OasWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Oas.PubSub,
  live_view: [signing_salt: "******REMOVED******"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
# config :oas, Oas.Mailer, adapter: Swoosh.Adapters.Local
config :oas, Oas.Mailer, adapter: Swoosh.Adapters.SMTP,
  relay: "smtp.gmail.com",
  username: "chrisjbishop155",
  port: 587,
  password: "***REMOVED***",
  auth: :always

# Swoosh API client is needed for adapters other than SMTP.
# config :swoosh, :api_client, false

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.0",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

IO.puts("env: #{config_env()}")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
