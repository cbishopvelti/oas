import Config

# config/runtime.exs runs at start-up, after the compile-time config files
# (config.exs and the env file it imports, e.g. v2_prod.exs or v3_staging.exs).
#
# Every setting below can be overridden with an environment variable:
#   * a variable that is set (and not empty) replaces the value from the file
#   * a variable that is unset or empty leaves the file's value alone
#
# So with no variables set, behaviour is exactly as before. See .env.example
# for the full list. At start-up Oas.Application logs which settings came from
# the environment and which came from the file (names only, never values).

# Start the phoenix server if environment is set and running in a release
if System.get_env("PHX_SERVER") && System.get_env("RELEASE_NAME") do
  config :oas, OasWeb.Endpoint, server: true
end

if config_env() != :test do
  read_env = fn name ->
    case System.get_env(name) do
      nil -> nil
      "" -> nil
      value -> value
    end
  end

  to_int = fn name, value ->
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> raise "environment variable #{name} must be a whole number, got: #{inspect(value)}"
    end
  end

  mailers = [Oas.Mailer, Oas.TokenMailer]

  mail_adapter = fn v ->
    case v do
      "smtp" -> Swoosh.Adapters.SMTP
      "local" -> Swoosh.Adapters.Local
      _ -> raise "environment variable MAIL_ADAPTER must be smtp or local, got: #{inspect(v)}"
    end
  end

  smtp_tls = fn v ->
    case v do
      "always" -> :always
      "if_available" -> :if_available
      "never" -> :never
      _ -> raise "environment variable SMTP_TLS must be always, if_available or never, got: #{inspect(v)}"
    end
  end

  # {env var, function that applies its value}
  overrides = [
    {"DB_FILE", fn v -> config :oas, Oas.Repo, database: v end},
    {"DB_BACKUP_PATH", fn v -> config :oas, Oas.Repo, backup_database: v end},
    {"SECRET_KEY_BASE", fn v -> config :oas, OasWeb.Endpoint, secret_key_base: v end},
    {"PHX_HOST", fn v -> config :oas, OasWeb.Endpoint, url: [host: v] end},
    {"PORT", fn v -> config :oas, OasWeb.Endpoint, http: [port: to_int.("PORT", v)] end},
    # Cookie domain for the session and remember-me cookies, read at runtime.
    {"DOMAIN", fn v -> config :oas, OasWeb.Endpoint, domain: v end},
    {"ADMIN_URL", fn v -> config :oas, app_url: v end},
    {"PUBLIC_URL", fn v -> config :oas, public_url: v end},
    {"MAIL_ADAPTER",
     fn v ->
       adapter = mail_adapter.(v)
       for m <- mailers, do: config(:oas, m, adapter: adapter)
     end},
    {"SMTP_RELAY", fn v -> for m <- mailers, do: config(:oas, m, relay: v) end},
    {"SMTP_PORT",
     fn v ->
       port = to_int.("SMTP_PORT", v)
       for m <- mailers, do: config(:oas, m, port: port)
     end},
    {"SMTP_USERNAME", fn v -> for m <- mailers, do: config(:oas, m, username: v) end},
    {"SMTP_PASSWORD", fn v -> for m <- mailers, do: config(:oas, m, password: v) end},
    {"SMTP_TLS",
     fn v ->
       tls = smtp_tls.(v)
       for m <- mailers, do: config(:oas, m, tls: tls)
     end},
    {"MAIL_FROM_ADDRESS",
     fn v ->
       name = read_env.("MAIL_FROM_NAME") || "OAS"
       config :oas, Oas.TokenMailer, from: {name, v}
     end},
    # Wins over the society name as the From name (see Oas.Mail).
    {"MAIL_FROM_NAME", fn v -> config :oas, mail_from_name: v end},
    {"LLM_STUDIO_URL", fn v -> config :oas, llm_sudio_url: v end},
    {"GOCARDLESS_BACKUP_DIR", fn v -> config :oas, gocardless_backup_dir: v end}
  ]

  if read_env.("MAIL_FROM_NAME") && !read_env.("MAIL_FROM_ADDRESS") do
    raise "MAIL_FROM_NAME is set but MAIL_FROM_ADDRESS is not. Set both, or only MAIL_FROM_ADDRESS."
  end

  {from_env, from_file} =
    Enum.reduce(overrides, {[], []}, fn {name, apply}, {env_acc, file_acc} ->
      case read_env.(name) do
        nil ->
          {env_acc, [name | file_acc]}

        value ->
          apply.(value)
          {[name | env_acc], file_acc}
      end
    end)

  # Browser origins (CORS and socket check_origin). Outside dev, only ADMIN_URL,
  # PUBLIC_URL and the server's own host are allowed; see OasWeb.Origins.
  # ALLOW_ANY_ORIGIN=true turns this off (escape hatch, not for normal use).
  allow_any_origin = read_env.("ALLOW_ANY_ORIGIN") == "true"

  if config_env() not in [:dev, :dev_mac] and not allow_any_origin do
    config :oas, :restrict_origins, true
    config :oas, OasWeb.Endpoint, check_origin: {OasWeb.Origins, :socket_allowed?, []}
  end

  from_env = if allow_any_origin, do: from_env ++ ["ALLOW_ANY_ORIGIN"], else: from_env

  config :oas, :config_sources,
    from_env: Enum.reverse(from_env),
    from_file: Enum.reverse(from_file)
end
