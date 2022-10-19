defmodule Oas.Repo do
  use Ecto.Repo,
    otp_app: :oas,
    # adapter: Ecto.Adapters.Postgres
    adapter: Ecto.Adapters.SQLite3
end
