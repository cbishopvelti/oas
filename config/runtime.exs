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

  # {env var, function that applies its value}
  overrides = [
    {"DB_FILE", fn v -> config :oas, Oas.Repo, database: v end},
    {"DB_BACKUP_PATH", fn v -> config :oas, Oas.Repo, backup_database: v end},
    {"SECRET_KEY_BASE", fn v -> config :oas, OasWeb.Endpoint, secret_key_base: v end},
    {"PHX_HOST", fn v -> config :oas, OasWeb.Endpoint, url: [host: v] end},
    {"PORT", fn v -> config :oas, OasWeb.Endpoint, http: [port: to_int.("PORT", v)] end},
    # Value only: the session cookie still reads :domain at compile time (item 1.3).
    {"DOMAIN", fn v -> config :oas, OasWeb.Endpoint, domain: v end},
    {"ADMIN_URL", fn v -> config :oas, app_url: v end},
    {"PUBLIC_URL", fn v -> config :oas, public_url: v end},
    {"SMTP_RELAY", fn v -> for m <- mailers, do: config(:oas, m, relay: v) end},
    {"SMTP_PORT",
     fn v ->
       port = to_int.("SMTP_PORT", v)
       for m <- mailers, do: config(:oas, m, port: port)
     end},
    {"SMTP_USERNAME", fn v -> for m <- mailers, do: config(:oas, m, username: v) end},
    {"SMTP_PASSWORD", fn v -> for m <- mailers, do: config(:oas, m, password: v) end},
    {"MAIL_FROM_ADDRESS",
     fn v ->
       name = read_env.("MAIL_FROM_NAME") || "OAS"
       config :oas, Oas.TokenMailer, from: {name, v}
     end},
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

  from_env = if read_env.("MAIL_FROM_NAME"), do: from_env ++ ["MAIL_FROM_NAME"], else: from_env

  config :oas, :config_sources,
    from_env: Enum.reverse(from_env),
    from_file: Enum.reverse(from_file)
end
