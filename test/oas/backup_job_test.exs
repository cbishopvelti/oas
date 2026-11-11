defmodule Oas.BackupJobTest do
  use ExUnit.Case, async: true

  alias Oas.BackupJob

  @now ~U[2026-11-11 03:00:00.000000Z]

  setup do
    dir = Path.join(System.tmp_dir!(), "oas-backup-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, dir: dir, prefix: Path.join(dir, "sqlite-backup")}
  end

  defp touch(dir, name) do
    path = Path.join(dir, name)
    File.write!(path, "x")
    path
  end

  defp stamp(days_ago), do: DateTime.add(@now, -days_ago * 86_400, :second) |> DateTime.to_iso8601()

  describe "old_backups/4" do
    test "selects only correctly named backups older than keep_days", %{dir: dir, prefix: prefix} do
      old = touch(dir, "sqlite-backup-#{stamp(31)}.db")
      _recent = touch(dir, "sqlite-backup-#{stamp(29)}.db")
      # Not written by Oas.Repo.backup/0, so never selected, however old.
      touch(dir, "sqlite-prod.db")
      touch(dir, "other-backup-#{stamp(40)}.db")
      touch(dir, "sqlite-backup-#{stamp(40)}.db.gz")
      touch(dir, "sqlite-backup-#{stamp(40)}.db-journal")
      touch(dir, "sqlite-backup-#{stamp(40)}.sqlite")
      touch(dir, "sqlite-backup-2020-01-01.db")
      touch(dir, "sqlite-backup-2020-01-01T00:00:00+01:00.db")
      touch(dir, "sqlite-backup-copy-#{stamp(40)}.db")
      touch(dir, "xsqlite-backup-#{stamp(40)}.db")
      File.mkdir_p!(Path.join(dir, "sqlite-backup-#{stamp(50)}.db"))

      assert BackupJob.old_backups(prefix, 30, @now, nil) == [old]
    end

    test "never selects the file just written", %{dir: dir, prefix: prefix} do
      keep = touch(dir, "sqlite-backup-#{stamp(31)}.db")
      other = touch(dir, "sqlite-backup-#{stamp(32)}.db")

      assert BackupJob.old_backups(prefix, 30, @now, keep) == [other]
    end

    test "never follows symlinks", %{dir: dir, prefix: prefix} do
      target = touch(dir, "precious.db")
      File.ln_s!(target, Path.join(dir, "sqlite-backup-#{stamp(40)}.db"))

      assert BackupJob.old_backups(prefix, 30, @now, nil) == []
    end

    test "keep_days 0 selects nothing", %{dir: dir, prefix: prefix} do
      touch(dir, "sqlite-backup-#{stamp(400)}.db")
      assert BackupJob.old_backups(prefix, 0, @now, nil) == []
    end

    test "missing directory selects nothing", %{dir: dir} do
      assert BackupJob.old_backups(Path.join([dir, "nope", "sqlite-backup"]), 30, @now, nil) == []
    end

    test "leaves files in other directories alone", %{dir: dir, prefix: prefix} do
      sub = Path.join(dir, "sub")
      File.mkdir_p!(sub)
      touch(sub, "sqlite-backup-#{stamp(40)}.db")
      assert BackupJob.old_backups(prefix, 30, @now, nil) == []
    end
  end

  describe "ms_until_next_run/3" do
    defp london(naive), do: DateTime.from_naive!(naive, "Europe/London")

    test "later the same day" do
      assert BackupJob.ms_until_next_run(london(~N[2026-11-11 01:00:00]), 3, 0) == 2 * 3_600_000
    end

    test "tomorrow when the time has passed, or is now" do
      assert BackupJob.ms_until_next_run(london(~N[2026-11-11 04:00:00]), 3, 0) == 23 * 3_600_000
      assert BackupJob.ms_until_next_run(london(~N[2026-11-11 03:00:00]), 3, 0) == 24 * 3_600_000
    end

    test "clocks go forward: 23 hours between 03:00s" do
      # 29 March 2026, 01:00 GMT -> 02:00 BST
      assert BackupJob.ms_until_next_run(london(~N[2026-03-28 03:00:00]), 3, 0) == 23 * 3_600_000
    end

    test "clocks go back: 25 hours between 03:00s" do
      # 25 October 2026, 02:00 BST -> 01:00 GMT
      assert BackupJob.ms_until_next_run(london(~N[2026-10-24 03:00:00]), 3, 0) == 25 * 3_600_000
    end

    test "a time skipped by clocks going forward runs just after the gap" do
      # 01:30 does not exist on 29 March 2026 in London; runs at 02:00 BST (01:00 UTC)
      ms = BackupJob.ms_until_next_run(london(~N[2026-03-29 00:00:00]), 1, 30)
      assert ms == 3_600_000
    end

    test "a repeated time runs the first time" do
      # 01:30 happens twice on 25 October 2026; first is 00:30 UTC, and
      # midnight local is still BST (23:00 UTC), so 90 minutes
      ms = BackupJob.ms_until_next_run(london(~N[2026-10-25 00:00:00]), 1, 30)
      assert ms == 90 * 60_000
    end

    test "other time zones" do
      now = DateTime.from_naive!(~N[2026-11-11 22:00:00], "America/New_York")
      assert BackupJob.ms_until_next_run(now, 3, 0) == 5 * 3_600_000
    end
  end
end
