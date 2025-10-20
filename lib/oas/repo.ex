import Ecto.Query, only: [from: 2]

defmodule Oas.Repo do
  use Ecto.Repo,
    otp_app: :oas,
    # adapter: Ecto.Adapters.Postgres
    adapter: Ecto.Adapters.SQLite3

  require Logger

  # @replicas [
  #   Oas.Repo.Replica1
  # ]
  # def replica do
  #   Enum.random(@replicas)
  # end

  # for repo <- @replicas do
  #   defmodule repo do
  #     use Ecto.Repo,
  #       otp_app: :oas,
  #       adapter: Ecto.Adapters.SQLite3,
  #       read_only: true
  #   end
  # end


  # Oas.Repo.is_backup_file_valid("./dbs/sqlite-backup-2025-10-20T13:47:51.342997Z.db")
  def is_backup_file_valid(path) do
    case Exqlite.Basic.open(path) do
      {:ok, conn} ->
        try do
          with {:ok, _a, %{rows: [_row]}, _b} <- Exqlite.Basic.exec(conn, "SELECT * FROM config_config WHERE TRUE") do
            true
          else
            _ -> false
          end
        after
          Exqlite.Basic.close(conn)
        end
      {:error, _} -> false
    end
  end

  # Oas.Repo.backup()
  def backup() do
    %{pid: _pid } = Ecto.Adapter.lookup_meta(Oas.Repo.get_dynamic_repo())

    {:ok, conn} = Exqlite.Sqlite3.open(
      Application.get_env(:oas, Oas.Repo)[:database]
    )

    when1 = DateTime.utc_now() |> DateTime.to_iso8601()

    file_path = Application.get_env(:oas, Oas.Repo)[:backup_database] <> "-" <> when1 <> ".db"
    {:ok, file} = File.open(file_path, [:write])

    {:ok, data} = Exqlite.Sqlite3.serialize(conn)

    data
    |> (&(IO.binwrite(file, &1))).()

    File.close(file)
    Exqlite.Sqlite3.close(conn)

    if !is_backup_file_valid(file_path) do
      Logger.error("The backup file is not valid")
      Application.stop(:oas)
      System.halt(1)
    end

    config = from(
      c in Oas.Config.Config,
      limit: 1
    ) |> Oas.Repo.one!()
    name = "oas" <> "-" <> when1 <> ".db"
    if (config.backup_recipient) do
      from = Application.get_env(:oas, Oas.TokenMailer)[:from]
      email = Swoosh.Email.new()
      |> Swoosh.Email.to({"backup_recipient", config.backup_recipient})
      |> Swoosh.Email.from(from)
      |> Swoosh.Email.subject("OAS backup")
      |> Swoosh.Email.text_body("Backup database\n")
      |> Swoosh.Email.attachment(
        Swoosh.Attachment.new(
          {:data, data},
          filename: name,
          content_type: "application/octet-stream",
          type: :inline
        )
      )
      Oas.Mailer.deliver(email)
    end
  end
end
