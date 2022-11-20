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

  def backup() do
    %{pid: pid } = Ecto.Adapter.lookup_meta(Oas.Repo.get_dynamic_repo())

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
  end
end
