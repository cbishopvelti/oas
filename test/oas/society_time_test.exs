defmodule Oas.SocietyTimeTest do
  @moduledoc """
  "Today" and "now" in business logic follow the society's time zone, not UTC.
  Each case runs with the zone set to Europe/London and to America/New_York.
  """
  use Oas.DataCase

  import Ecto.Query, only: [from: 2]

  alias Oas.Settings
  alias Oas.Trainings.{RecurringServer, TrainingWhereTime}

  setup do
    on_exit(fn -> Settings.put_test_utc_now(nil) end)
    :ok
  end

  defp set_zone(zone) do
    {:ok, _} = Settings.update_config(%{time_zone: zone}, [:time_zone])
  end

  defp at(iso) do
    {:ok, utc, 0} = DateTime.from_iso8601(iso)
    utc
  end

  defp freeze(iso), do: Settings.put_test_utc_now(at(iso))

  defp local(naive, zone), do: DateTime.from_naive!(naive, zone)

  # {zone, last second before local midnight (UTC), local date before}
  @midnights [
    {"Europe/London", "2026-01-15T23:59:59Z", ~D[2026-01-15]},
    {"Europe/London", "2026-06-15T22:59:59Z", ~D[2026-06-15]},
    {"America/New_York", "2026-01-16T04:59:59Z", ~D[2026-01-15]},
    {"America/New_York", "2026-06-16T03:59:59Z", ~D[2026-06-15]}
  ]

  describe "Settings.today/now" do
    for {zone, before_midnight, date} <- @midnights do
      @zone zone
      @before_midnight before_midnight
      @date date
      test "#{zone}: the date turns over at local midnight (#{date})" do
        set_zone(@zone)
        before = at(@before_midnight)
        assert Settings.today(before) == @date
        assert Settings.today(DateTime.add(before, 1)) == Date.add(@date, 1)

        freeze(@before_midnight)
        assert Settings.today() == @date
        assert Settings.now().time_zone == @zone
      end
    end

    test "Europe/London: both clock changes" do
      set_zone("Europe/London")

      # Spring forward: 01:00 GMT becomes 02:00 BST.
      assert Settings.now(at("2026-03-29T00:59:59Z")) |> DateTime.to_naive() ==
               ~N[2026-03-29 00:59:59]
      assert Settings.now(at("2026-03-29T01:00:00Z")) |> DateTime.to_naive() ==
               ~N[2026-03-29 02:00:00]
      # The first midnight after the change is 23:00 UTC.
      assert Settings.today(at("2026-03-29T22:59:59Z")) == ~D[2026-03-29]
      assert Settings.today(at("2026-03-29T23:00:00Z")) == ~D[2026-03-30]

      # Fall back: 02:00 BST becomes 01:00 GMT, so 01:xx happens twice.
      assert Settings.now(at("2026-10-25T00:59:59Z")) |> DateTime.to_naive() ==
               ~N[2026-10-25 01:59:59]
      assert Settings.now(at("2026-10-25T01:00:00Z")) |> DateTime.to_naive() ==
               ~N[2026-10-25 01:00:00]
      # Midnight before the change is 23:00 UTC, the one after is 00:00 UTC.
      assert Settings.today(at("2026-10-24T22:59:59Z")) == ~D[2026-10-24]
      assert Settings.today(at("2026-10-24T23:00:00Z")) == ~D[2026-10-25]
      assert Settings.today(at("2026-10-25T23:59:59Z")) == ~D[2026-10-25]
      assert Settings.today(at("2026-10-26T00:00:00Z")) == ~D[2026-10-26]
    end

    test "America/New_York: both clock changes" do
      set_zone("America/New_York")

      # Spring forward: 02:00 EST becomes 03:00 EDT.
      assert Settings.now(at("2026-03-08T06:59:59Z")) |> DateTime.to_naive() ==
               ~N[2026-03-08 01:59:59]
      assert Settings.now(at("2026-03-08T07:00:00Z")) |> DateTime.to_naive() ==
               ~N[2026-03-08 03:00:00]
      assert Settings.today(at("2026-03-09T03:59:59Z")) == ~D[2026-03-08]
      assert Settings.today(at("2026-03-09T04:00:00Z")) == ~D[2026-03-09]

      # Fall back: 02:00 EDT becomes 01:00 EST.
      assert Settings.now(at("2026-11-01T05:59:59Z")) |> DateTime.to_naive() ==
               ~N[2026-11-01 01:59:59]
      assert Settings.now(at("2026-11-01T06:00:00Z")) |> DateTime.to_naive() ==
               ~N[2026-11-01 01:00:00]
      assert Settings.today(at("2026-11-01T03:59:59Z")) == ~D[2026-10-31]
      assert Settings.today(at("2026-11-01T04:00:00Z")) == ~D[2026-11-01]
      assert Settings.today(at("2026-11-02T04:59:59Z")) == ~D[2026-11-01]
      assert Settings.today(at("2026-11-02T05:00:00Z")) == ~D[2026-11-02]
    end

    test "local_today follows the frozen clock" do
      set_zone("America/New_York")
      freeze("2026-07-01T03:00:00Z")
      assert TrainingWhereTime.local_today() == ~D[2026-06-30]
    end
  end

  describe "credit expiry on the boundary day" do
    defp credit_expiring(member) do
      %Oas.Transactions.Transaction{}
      |> Ecto.Changeset.cast(
        %{
          who: member.name,
          who_member_id: member.id,
          what: "Credit",
          amount: Decimal.new("5"),
          when: ~D[2026-01-01],
          type: "INCOMING",
          my_reference: "test reference"
        },
        [:who, :who_member_id, :what, :amount, :when, :type, :my_reference]
      )
      |> Oas.Credits.Credit.doCredit(%{amount: Decimal.new("5")})
      |> Oas.Repo.insert!()

      from(c in Oas.Credits.Credit, where: c.who_member_id == ^member.id, select: c.expires_on)
      |> Oas.Repo.one!()
    end

    defp total(member) do
      {_, total} = Oas.Credits.Credit2.get_credit_amount(%{member_id: member.id})
      Decimal.to_float(total)
    end

    for zone <- ["Europe/London", "America/New_York"] do
      @zone zone
      test "#{zone}: a credit is spent until local midnight before its expiry date" do
        set_zone(@zone)
        member = Oas.MembersFixtures.member_fixture()
        expires_on = credit_expiring(member)

        # Local midnight at the start of expires_on, as a UTC instant.
        midnight =
          DateTime.new!(expires_on, ~T[00:00:00], @zone) |> DateTime.shift_zone!("Etc/UTC")

        Settings.put_test_utc_now(DateTime.add(midnight, -1))
        assert Settings.today() == Date.add(expires_on, -1)
        assert total(member) == 5.0

        Settings.put_test_utc_now(midnight)
        assert Settings.today() == expires_on
        assert total(member) == 0.0
      end
    end

    test "America/New_York: late evening is still the day before, though UTC has moved on" do
      set_zone("America/New_York")
      member = Oas.MembersFixtures.member_fixture()
      expires_on = credit_expiring(member)

      # 23:30 local the day before expiry is already expires_on in UTC.
      late =
        DateTime.new!(Date.add(expires_on, -1), ~T[23:30:00], "America/New_York")
        |> DateTime.shift_zone!("Etc/UTC")

      assert DateTime.to_date(late) == expires_on
      Settings.put_test_utc_now(late)
      assert total(member) == 5.0
    end
  end

  describe "recurring scheduler" do
    # Tuesday 19:00 to 21:00
    @tuesday %TrainingWhereTime{day_of_week: 2, start_time: ~T[19:00:00], end_time: ~T[21:00:00]}

    for zone <- ["Europe/London", "America/New_York"] do
      @zone zone
      test "#{zone}: today's session counts until it ends in local time" do
        now = local(~N[2026-11-10 20:59:00], @zone)
        assert [{:event_not_finished, {_, ~D[2026-11-10]}} = e] =
                 RecurringServer.calculate_events([@tuesday], now)
        assert RecurringServer.next_run_ms([e], now) == 60_000

        now = local(~N[2026-11-10 21:00:00], @zone)
        assert [{:ok, {_, ~D[2026-11-17]}} = e] = RecurringServer.calculate_events([@tuesday], now)
        assert RecurringServer.next_run_ms([e], now) == :timer.hours(24 * 7)
      end

      test "#{zone}: the day turns over at local midnight" do
        wednesday = %{@tuesday | day_of_week: 3}

        now = local(~N[2026-11-10 23:59:59], @zone)
        assert [{:ok, {_, ~D[2026-11-11]}}] = RecurringServer.calculate_events([wednesday], now)

        now = local(~N[2026-11-11 00:00:00], @zone)
        assert [{:event_not_finished, {_, ~D[2026-11-11]}}] =
                 RecurringServer.calculate_events([wednesday], now)
      end
    end

    test "next run across the clock changes" do
      # Autumn: the week is an hour longer.
      for {zone, tue} <- [{"Europe/London", ~D[2026-10-20]}, {"America/New_York", ~D[2026-10-27]}] do
        now = local(NaiveDateTime.new!(tue, ~T[21:00:00]), zone)
        events = RecurringServer.calculate_events([@tuesday], now)
        assert [{:ok, {_, next}}] = events
        assert next == Date.add(tue, 7)
        assert RecurringServer.next_run_ms(events, now) == :timer.hours(24 * 7 + 1)
      end

      # Spring: an hour shorter.
      for {zone, tue} <- [{"Europe/London", ~D[2026-03-24]}, {"America/New_York", ~D[2026-03-03]}] do
        now = local(NaiveDateTime.new!(tue, ~T[21:00:00]), zone)
        events = RecurringServer.calculate_events([@tuesday], now)
        assert RecurringServer.next_run_ms(events, now) == :timer.hours(24 * 7 - 1)
      end
    end

    test "a session ending in the skipped or repeated hour" do
      # Sunday sessions ending at 01:30 / 02:30 local, on the change-over nights.
      cases = [
        # spring gap: runs at the first moment after the gap
        {"Europe/London", ~N[2026-03-28 23:00:00], ~T[01:30:00], :timer.hours(2)},
        {"America/New_York", ~N[2026-03-07 23:00:00], ~T[02:30:00], :timer.hours(3)},
        # autumn repeat: runs at the first occurrence
        {"Europe/London", ~N[2026-10-24 23:00:00], ~T[01:30:00], :timer.minutes(150)},
        {"America/New_York", ~N[2026-10-31 23:00:00], ~T[01:30:00], :timer.minutes(150)}
      ]

      for {zone, now, end_time, expected_ms} <- cases do
        sunday = %TrainingWhereTime{day_of_week: 7, start_time: ~T[00:00:00], end_time: end_time}
        now = local(now, zone)
        events = RecurringServer.calculate_events([sunday], now)
        assert [{:ok, {_, sun}}] = events
        assert Date.day_of_week(sun) == 7
        assert RecurringServer.next_run_ms(events, now) == expected_ms, zone
      end
    end

    test "no events means no next run" do
      assert RecurringServer.next_run_ms([], local(~N[2026-11-10 12:00:00], "Europe/London")) ==
               nil
    end

    for zone <- ["Europe/London", "America/New_York"] do
      @zone zone
      test "#{zone}: check_and_create_recurring_events creates the training for the local date" do
        set_zone(@zone)

        where =
          %Oas.Trainings.TrainingWhere{name: "Recurring #{System.unique_integer()}"}
          |> Oas.Repo.insert!()

        %TrainingWhereTime{
          training_where_id: where.id,
          day_of_week: 3,
          start_time: ~T[19:00:00],
          end_time: ~T[21:00:00],
          recurring: true
        }
        |> Oas.Repo.insert!()

        # Tuesday 22:00 local. In New York that is already Wednesday in UTC,
        # where the old UTC logic would have treated Wednesday's session as today.
        now = local(~N[2026-11-10 22:00:00], @zone)
        timer = RecurringServer.check_and_create_recurring_events(now)
        if timer, do: Process.cancel_timer(timer)

        dates =
          from(t in Oas.Trainings.Training, where: t.training_where_id == ^where.id, select: t.when)
          |> Oas.Repo.all()

        assert dates == [~D[2026-11-11]]
      end
    end
  end
end
