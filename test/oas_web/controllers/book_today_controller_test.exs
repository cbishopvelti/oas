defmodule OasWeb.BookTodayControllerTest do
  use OasWeb.ConnCase

  alias OasWeb.BookTodayController

  setup :register_and_log_in_member

  setup do
    on_exit(fn -> Oas.Settings.put_test_utc_now(nil) end)
    :ok
  end

  describe "get_one_training/2" do
    test "picks the session nearest the society's wall-clock time" do
      morning = %{id: 1, start_time: ~T[10:00:00], end_time: ~T[12:00:00]}
      evening = %{id: 2, start_time: ~T[18:00:00], end_time: ~T[20:00:00]}
      now = DateTime.new!(~D[2026-11-10], ~T[18:30:00], "America/New_York")

      assert BookTodayController.get_one_training([morning, evening], now) == {:ok, evening}
    end
  end

  describe "GET /book-today" do
    # 2026-11-11 03:00 UTC is still Tuesday 10 November in New York.
    setup do
      where =
        %Oas.Trainings.TrainingWhere{name: "Book today #{System.unique_integer()}"}
        |> Oas.Repo.insert!()

      # Two sessions with no times, so a match stops at "more than one event"
      # instead of booking.
      for _ <- 1..2 do
        %Oas.Trainings.Training{when: ~D[2026-11-10], training_where_id: where.id, is_active: true}
        |> Oas.Repo.insert!()
      end

      Oas.Settings.put_test_utc_now(~U[2026-11-11 03:00:00Z])
      :ok
    end

    test "finds today's training by the society's date", %{conn: conn} do
      {:ok, _} = Oas.Settings.update_config(%{time_zone: "America/New_York"}, [:time_zone])
      conn = get(conn, "/book-today")
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "more than one event today"
    end

    test "Europe/London is already the next day", %{conn: conn} do
      {:ok, _} = Oas.Settings.update_config(%{time_zone: "Europe/London"}, [:time_zone])
      conn = get(conn, "/book-today")
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "No events found today."
    end
  end
end
