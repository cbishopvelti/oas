defmodule Oas.Repo do
  use Ecto.Repo,
    otp_app: :oas,
    # adapter: Ecto.Adapters.Postgres
    adapter: Ecto.Adapters.SQLite3,
    json_library: Jason

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

    config = Oas.Settings.get_config!()
    name = Oas.Settings.society_slug() <> "-" <> when1 <> ".db"
    if (config.backup_recipient) do
      send_backup_email(config.backup_recipient, name, data)
    end
  end

  @backup_warning_key :backup_email_failed

  # Emails the backup gzipped (the attachment is named `filename <> ".gz"`).
  # A failed send is logged and raised as an admin global warning; the next
  # successful send clears that warning. Returns the result of Oas.Mail.deliver.
  def send_backup_email(recipient, filename, data) do
    result =
      try do
        Oas.Mail.deliver(
          {"backup_recipient", recipient},
          "#{Oas.Settings.society_name()} backup",
          "Backup database, gzipped. Restore with: gunzip #{filename}.gz\n",
          attachments: [
            Swoosh.Attachment.new({:data, :zlib.gzip(data)},
              filename: filename <> ".gz",
              content_type: "application/gzip"
            )
          ]
        )
      rescue
        e -> {:error, Exception.message(e)}
      end

    case result do
      {:ok, _} ->
        if :ets.lookup(:global_warnings, @backup_warning_key) != [] do
          Oas.Gocardless.delete_warning(@backup_warning_key)
        end

      error ->
        Logger.error("Backup email to #{recipient} failed: #{inspect(error)}")

        Oas.Gocardless.send_warning(
          @backup_warning_key,
          "The backup email to #{recipient} failed on " <>
            "#{Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d %H:%M:%S")} UTC: #{inspect(error)}. " <>
            "The backup file was still written to disk."
        )
    end

    result
  end
end
