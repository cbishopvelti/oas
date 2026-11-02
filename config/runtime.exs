import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.


# Start the phoenix server if environment is set and running in a release
if System.get_env("PHX_SERVER") && System.get_env("RELEASE_NAME") do
  config :oas, OasWeb.Endpoint, server: true
end

# Secrets are read from environment variables, never from committed config.
# In prod-like environments (gcloud, gcloud_dev, v2_prod, v3_staging, ...)
# the required variables must be set or boot fails with a clear error.
# In dev, dev_mac and test they are optional and override the local defaults.
# See "Secrets" in README.md for the full list.
prod_like? = config_env() not in [:dev, :dev_mac, :test]

env_secret = fn name, hint ->
  case System.get_env(name) do
    value when value in [nil, ""] ->
      if prod_like? do
        raise """
        environment variable #{name} is missing (MIX_ENV=#{config_env()}).
        #{hint}
        """
      end

      nil

    value ->
      value
  end
end

secret_key_base =
  env_secret.("SECRET_KEY_BASE", "Generate one with: mix phx.gen.secret")

live_view_signing_salt =
  env_secret.("LIVE_VIEW_SIGNING_SALT", "Generate one with: mix phx.gen.secret 32")

smtp_password =
  env_secret.("SMTP_PASSWORD", "Use the Gmail app password for the SMTP account.")

if secret_key_base do
  config :oas, OasWeb.Endpoint, secret_key_base: secret_key_base
end

if live_view_signing_salt do
  config :oas, OasWeb.Endpoint, live_view: [signing_salt: live_view_signing_salt]
end

smtp_credentials =
  [username: System.get_env("SMTP_USERNAME"), password: smtp_password]
  |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)

if smtp_credentials != [] do
  # Merged into the adapter settings from the env config file; harmless
  # for mailers that use the Local/Test adapter.
  config :oas, Oas.Mailer, smtp_credentials
  config :oas, Oas.TokenMailer, smtp_credentials
end


if config_env() == :prod and false do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6"), do: [:inet6], else: []

  config :oas, Oas.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :oas, OasWeb.Endpoint,
    url: [host: host, port: 443],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## Using releases
  #
  # If you are doing OTP releases, you need to instruct Phoenix
  # to start each relevant endpoint:
  #
  #     config :oas, OasWeb.Endpoint, server: true
  #
  # Then you can assemble a release by calling `mix release`.
  # See `mix help release` for more information.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
      #  config :oas, Oas.Mailer,
      #    adapter: Swoosh.Adapters.Mailgun,
      #    api_key: System.get_env("MAILGUN_API_KEY"),
      #    domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
