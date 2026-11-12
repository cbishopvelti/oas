defmodule Oas.BackupJob do
  @moduledoc """
  Runs the database backup once a day at a fixed local time in the society's
  time zone (`:backup_time`, default 03:00, env `BACKUP_TIME=HH:MM`), then
  deletes backup files older than `:backup_keep_days` (default 30, env
  `BACKUP_KEEP_DAYS`; 0 never deletes).

  The next run is worked out again after every run, so a clock change or a
  change of society time zone is picked up the next day.

  Old backups are only deleted after a backup that was written and passed
  `Oas.Repo.is_backup_file_valid/1`, and only files that `Oas.Repo.backup/0`
  itself writes: in the backup directory, named exactly
  `<prefix>-<ISO 8601 UTC timestamp>.db`, regular files, dated by the
  timestamp in the name. The file just written is never deleted.
  """
  use GenServer

  require Logger

  @default_time {3, 0}
  @default_keep_days 30

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @impl true
  def init(state) do
    schedule()
    {:ok, state}
  end

  @impl true
  def handle_info(:backup, state) do
    Logger.info("Running backup ...")

    try do
      case Oas.Repo.backup() do
        {:ok, file_path} ->
          Logger.info("Backup written to #{file_path}")
          prune(file_path)

        other ->
          Logger.error("Backup did not complete, not deleting old backups: #{inspect(other)}")
      end
    rescue
      e ->
        Logger.error(
          "Backup failed, not deleting old backups: " <>
            Exception.format(:error, e, __STACKTRACE__)
        )
    end

    schedule()
    {:noreply, state}
  end

  defp schedule() do
    {hour, minute} = backup_time()
    ms = ms_until_next_run(Oas.Settings.now(), hour, minute)
    Logger.info("Next backup in #{div(ms, 60_000)} minutes (#{pad(hour)}:#{pad(minute)} #{Oas.Settings.time_zone()})")
    Process.send_after(self(), :backup, ms)
  end

  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")

  def backup_time, do: Application.get_env(:oas, :backup_time, @default_time)

  def keep_days, do: Application.get_env(:oas, :backup_keep_days, @default_keep_days)

  @doc """
  Milliseconds from `now` (a `DateTime` in the society's zone) until the next
  `hour:minute` local time in that zone, strictly in the future. On a day where
  that time does not exist (clocks go forward) it runs at the first moment
  after the gap; where it happens twice (clocks go back) it runs the first time.
  """
  def ms_until_next_run(%DateTime{} = now, hour, minute) do
    time = Time.new!(hour, minute, 0)
    date = DateTime.to_date(now)

    next =
      [date, Date.add(date, 1), Date.add(date, 2)]
      |> Enum.map(&local_datetime(&1, time, now.time_zone))
      |> Enum.find(&(DateTime.compare(&1, now) == :gt))

    max(DateTime.diff(next, now, :millisecond), 0)
  end

  defp local_datetime(date, time, zone) do
    case DateTime.new(date, time, zone) do
      {:ok, dt} -> dt
      {:gap, _before, just_after} -> just_after
      {:ambiguous, first, _second} -> first
    end
  end

  @doc """
  Deletes backups older than `keep_days/0`, never `keep_path`. Logs each file
  it deletes. Returns the list of deleted paths.
  """
  def prune(keep_path) do
    prefix = Application.get_env(:oas, Oas.Repo)[:backup_database]

    case keep_days() do
      0 ->
        []

      days ->
        prefix
        |> old_backups(days, DateTime.utc_now(), keep_path)
        |> Enum.flat_map(fn path ->
          case File.rm(path) do
            :ok ->
              Logger.info("Deleted old backup #{path}")
              [path]

            {:error, reason} ->
              Logger.error("Could not delete old backup #{path}: #{inspect(reason)}")
              []
          end
        end)
    end
  end

  @doc """
  The backup files written under `prefix` (as `Oas.Repo.backup/0` names them)
  whose timestamp is more than `keep_days` days before `now_utc`, excluding
  `keep_path`. Pure apart from listing the directory; deletes nothing.
  """
  def old_backups(prefix, keep_days, %DateTime{} = now_utc, keep_path)
      when is_binary(prefix) and is_integer(keep_days) and keep_days > 0 do
    dir = Path.dirname(prefix)
    base = Path.basename(prefix) <> "-"
    cutoff = DateTime.add(now_utc, -keep_days * 86_400, :second)
    keep = keep_path && Path.expand(keep_path)

    case File.ls(dir) do
      {:ok, names} ->
        names
        |> Enum.sort()
        |> Enum.filter(fn name ->
          case backup_timestamp(name, base) do
            {:ok, ts} -> DateTime.compare(ts, cutoff) == :lt
            :error -> false
          end
        end)
        |> Enum.map(&Path.join(dir, &1))
        |> Enum.reject(&(Path.expand(&1) == keep))
        |> Enum.filter(&regular_file?/1)

      {:error, reason} ->
        Logger.error("Could not list backup directory #{dir}: #{inspect(reason)}")
        []
    end
  end

  def old_backups(_prefix, _keep_days, _now_utc, _keep_path), do: []

  # The timestamp of a file named exactly `<base><ISO 8601 UTC>.db`, as
  # written by Oas.Repo.backup/0 (DateTime.utc_now() |> DateTime.to_iso8601()).
  # The timestamp must round-trip, so nothing else with a similar name matches.
  defp backup_timestamp(name, base) do
    with true <- String.starts_with?(name, base),
         true <- String.ends_with?(name, ".db"),
         stamp = name |> String.replace_prefix(base, "") |> String.replace_suffix(".db", ""),
         {:ok, dt, 0} <- DateTime.from_iso8601(stamp),
         true <- DateTime.to_iso8601(dt) == stamp do
      {:ok, dt}
    else
      _ -> :error
    end
  end

  defp regular_file?(path) do
    match?({:ok, %File.Stat{type: :regular}}, File.lstat(path))
  end
end
