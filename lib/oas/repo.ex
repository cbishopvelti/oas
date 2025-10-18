import Ecto.Query, only: [from: 2]

defmodule Oas.Repo do
  use Ecto.Repo,
    otp_app: :oas,
    # adapter: Ecto.Adapters.Postgres
    adapter: Ecto.Adapters.SQLite3

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

  # Oas.Repo.backup()
  def backup() do
    %{pid: _pid } = Ecto.Adapter.lookup_meta(Oas.Repo.get_dynamic_repo())

    {:ok, conn} = Exqlite.Sqlite3.open(
      Application.get_env(:oas, Oas.Repo)[:database]
    )

    when1 = DateTime.utc_now() |> DateTime.to_iso8601()


    {:ok, file} = File.open(Application.get_env(:oas, Oas.Repo)[:backup_database] <> "-" <> when1 <> ".db", [:write])

    {:ok, data} = Exqlite.Sqlite3.serialize(conn)

    data
    |> (&(IO.binwrite(file, &1))).()

    File.close(file)
    Exqlite.Sqlite3.close(conn)

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
