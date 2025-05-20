defmodule Oas.MixProject do
  use Mix.Project

  def project do
    [
      app: :oas,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      # compilers: [:gettext] ++ Mix.compilers(),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Oas.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bcrypt_elixir, "~> 3.2.1"},
      {:phoenix, "~> 1.7.18"},
      {:phoenix_view, "~> 2.0"},
      {:phoenix_ecto, "~> 4.6.3"},
      {:ecto_sql, "~> 3.12.1"},
      {:postgrex, ">= 0.0.0"},
      {:ecto_sqlite3, "~> 0.18.1"},
      {:exqlite, "~> 0.29.0"},
      {:phoenix_html, "~> 4.2.0"},
      {:phoenix_html_helpers, "~> 1.0"},
      {:phoenix_live_reload, "~> 1.5.3"},
      {:phoenix_live_view, "~> 1.0.3"},
      {:floki, "~> 0.37.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.6"},
      {:esbuild, "~> 0.3"}, # , runtime: Mix.env() == :dev
      {:hackney, "~> 1.18"},
      {:gen_smtp, "~> 1.2"},
      {:swoosh, "~> 1.3"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.18"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},
      {:absinthe, "~> 1.7.8"},
      {:absinthe_plug, "~> 1.5.8"},
      {:absinthe_phoenix, "~> 2.0"},
      {:corsica, "~> 1.2"},
      {:csv, "~> 3.0"},
      {:nimble_csv, "~> 1.2"},
      {:timex, "~> 3.7"},
      {:dialyxir, "~> 1.4.5"}
      # {:nx, "~> 0.9.2"},
      # {:bumblebee, "~> 0.6.0"},
      # {:exla, "~> 0.9.2"}, # Hardware acceleration (optional but recommended)
      # {:explorer, "~> 0.10.1"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.deploy": ["esbuild default --minify", "phx.digest"]
    ]
  end
end
