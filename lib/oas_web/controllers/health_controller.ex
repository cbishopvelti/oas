defmodule OasWeb.HealthController do
  @moduledoc """
  Serves `GET /health`: 200 when a trivial query on Oas.Repo succeeds, else 503.
  Also reports when the last backup ran (since start-up) and whether it was valid.
  Holds no secrets or settings.
  """
  use OasWeb, :controller

  require Logger

  def show(conn, _params) do
    db_ok = db_check().()
    backup = Oas.Repo.last_backup()

    body = %{
      status: if(db_ok, do: "ok", else: "error"),
      db: if(db_ok, do: "ok", else: "error"),
      last_backup_at: backup && DateTime.to_iso8601(backup.at),
      last_backup_valid: backup && backup.valid
    }

    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_status(if db_ok, do: 200, else: 503)
    |> json(body)
  end

  # Tests swap the check through `config :oas, :health_db_check, fun`.
  defp db_check(), do: Application.get_env(:oas, :health_db_check, &db_ok?/0)

  def db_ok?() do
    case Ecto.Adapters.SQL.query(Oas.Repo, "SELECT 1", []) do
      {:ok, _} -> true
      {:error, error} ->
        Logger.error("Health check query failed: #{inspect(error)}")
        false
    end
  rescue
    e ->
      Logger.error("Health check query failed: #{Exception.message(e)}")
      false
  end
end
