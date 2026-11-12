defmodule Mix.Tasks.Oas.Provision do
  @shortdoc "Sets up a new society: migrations, settings and the first admin"

  @moduledoc """
  Sets up a new society's database.

      mix oas.provision --name "Bristol Acro" --time-zone Europe/London \\
        --currency GBP --admin-email admin@example.com --admin-name "Sam Smith"

  It runs the migrations, sets the society name, time zone and currency
  (validated the same way as the admin Config page), and creates the first
  admin member if no member has that email. For a new admin it prints a link
  to set their password, the same link the reset password email sends, valid
  for one day. Nothing is emailed and no password is asked for or shown.

  Running it again with the same values changes nothing and says so. Add
  `--new-link` to print a fresh set-password link for an existing admin (for
  example when the first one expired before it was used).

  The link uses the server's URL (`PHX_HOST`), so run it with the same
  environment as the server, e.g. `docker exec -it oas mix oas.provision ...`.
  It does not start the web server, so it is safe to run next to a running one.
  """

  use Mix.Task

  @switches [
    name: :string,
    time_zone: :string,
    currency: :string,
    admin_email: :string,
    admin_name: :string,
    new_link: :boolean
  ]

  @required [:name, :time_zone, :currency, :admin_email, :admin_name]

  @impl Mix.Task
  def run(args) do
    opts = parse!(args)

    Mix.Task.run("app.config")
    {:ok, _} = Application.ensure_all_started(:phoenix)

    {:ok, result, _} =
      Ecto.Migrator.with_repo(Oas.Repo, fn repo ->
        case Ecto.Migrator.run(repo, :up, all: true, log: false) do
          [] -> Mix.shell().info("Migrations: already up to date")
          ran -> Mix.shell().info("Migrations: ran #{length(ran)}")
        end

        start_endpoint()
        Oas.Provision.run(opts)
      end)

    report(result)
  end

  @doc false
  def parse!(args) do
    {opts, rest, invalid} = OptionParser.parse(args, strict: @switches)

    cond do
      invalid != [] ->
        Mix.raise(
          "Unknown or invalid option: #{invalid |> Enum.map(&elem(&1, 0)) |> Enum.join(", ")}"
        )

      rest != [] ->
        Mix.raise("Unexpected argument: #{Enum.join(rest, " ")}")

      true ->
        opts = Map.new(opts)

        missing =
          for key <- @required,
              blank?(opts[key]),
              do: "--" <> String.replace(to_string(key), "_", "-")

        if missing != [], do: Mix.raise("Missing: #{Enum.join(missing, ", ")}")
        opts
    end
  end

  defp blank?(nil), do: true
  defp blank?(s), do: String.trim(s) == ""

  # The set-password link is built from the endpoint's URL config, which needs
  # the endpoint started. server: false keeps it off the network.
  defp start_endpoint do
    config = Application.get_env(:oas, OasWeb.Endpoint, [])
    Application.put_env(:oas, OasWeb.Endpoint, Keyword.put(config, :server, false))
    {:ok, _} = OasWeb.Endpoint.start_link()
  end

  defp report({:error, step, %Ecto.Changeset{} = changeset}) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {k, v}, acc -> String.replace(acc, "%{#{k}}", to_string(v)) end)
      end)
      |> Enum.map(fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)

    Mix.raise("Nothing saved. Invalid #{step}: #{Enum.join(errors, "; ")}")
  end

  defp report({:error, step, message}), do: Mix.raise("Nothing saved. #{step}: #{message}")

  defp report({:ok, report}) do
    shell = Mix.shell()

    case report.settings do
      [] ->
        shell.info("Settings: already set")

      changes ->
        for {field, old, new} <- changes do
          shell.info("Settings: #{field} #{inspect(old)} -> #{inspect(new)}")
        end
    end

    case report.admin do
      :created ->
        shell.info("Admin: created #{report.admin_email}")

      :exists ->
        shell.info("Admin: #{report.admin_email} already exists")

      :exists_not_admin ->
        shell.error(
          "Admin: a member with #{report.admin_email} exists but is not an admin. " <>
            "Left unchanged; make them an admin from the admin site, or use another email."
        )
    end

    if report.link do
      shell.info("""

      Set-password link for #{report.admin_email} (valid for 1 day, do not share):
      #{report.link}
      """)
    end

    if Oas.Provision.unchanged?(report), do: shell.info("Nothing changed.")
  end
end
