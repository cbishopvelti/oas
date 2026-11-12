defmodule OasWeb.HealthControllerTest do
  # Not async: swaps app env and the in-memory last-backup record.
  use OasWeb.ConnCase, async: false

  setup do
    on_exit(fn ->
      Application.delete_env(:oas, :health_db_check)
      :persistent_term.erase({Oas.Repo, :last_backup})
    end)

    :persistent_term.erase({Oas.Repo, :last_backup})
    :ok
  end

  test "GET /health is 200 with no backup yet", %{conn: conn} do
    conn = get(conn, "/health")

    assert json_response(conn, 200) == %{
             "status" => "ok",
             "db" => "ok",
             "last_backup_at" => nil,
             "last_backup_valid" => nil
           }

    assert conn.resp_cookies == %{}
  end

  test "GET /health reports the last backup", %{conn: conn} do
    at = ~U[2026-11-11 03:00:00.000000Z]
    :persistent_term.put({Oas.Repo, :last_backup}, %{at: at, valid: true})

    body = conn |> get("/health") |> json_response(200)
    assert body["last_backup_at"] == DateTime.to_iso8601(at)
    assert body["last_backup_valid"] == true
  end

  test "GET /health is 503 when the database query fails", %{conn: conn} do
    Application.put_env(:oas, :health_db_check, fn -> false end)

    assert json_response(get(conn, "/health"), 503) == %{
             "status" => "error",
             "db" => "error",
             "last_backup_at" => nil,
             "last_backup_valid" => nil
           }
  end

  test "db_ok? runs a real query" do
    assert OasWeb.HealthController.db_ok?()
  end
end
