defmodule Oas.Trainings.RecurringServer do
  use GenServer
  import Ecto.Query, only: [from: 2]
  require Logger

  def start_link(init_args) do
    GenServer.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  def init(_init_args) do
    send(self(), :after_join)
    {:ok, %{timer: nil}}
  end

  def maybe_create_event(training_where_time, when1) do
    training_where = training_where_time.training_where
    # Check in-memory first (based on what we just fetched)
    case Enum.any?(training_where.trainings, fn %{when: when2} -> when1 == when2 end)
      or Enum.any?(training_where.training_deleted, fn %{when: when2} -> when1 == when2 end)
    do
      true ->
        nil
      false ->
        %Oas.Trainings.Training{}
        |> Ecto.Changeset.cast(%{
          when: when1,
          notes: nil,
          commitment: false,
          limit: Map.get(training_where_time, :limit) ||
            Map.get(training_where, :limit),
          start_time: training_where_time.start_time,
          end_time: training_where_time.end_time,
          booking_offset: training_where_time.booking_offset,
          venue_billing_type: training_where.billing_type,
          venue_billing_config: training_where.billing_config
        }, [
          :when, :notes, :commitment, :limit,
          :start_time, :end_time, :booking_offset,
          :venue_billing_type, :venue_billing_config
        ])
        |> Ecto.Changeset.put_assoc(:training_where, training_where)
        |> Oas.Repo.insert() # This might raise if a DB Unique Index is hit
    end
  end

  # Oas.Trainings.RecurringServer.check_and_create_recurring_events()
  #
  # Training dates and start/end times are wall-clock values in the society's
  # time zone, so "now" is too. `now_local` is only passed in by tests.
  def check_and_create_recurring_events(now_local \\ Oas.Settings.now()) do
    now = DateTime.to_date(now_local)

    # --- STEP 1: READ & CALCULATE (Outside Transaction) ---
    # We fetch data and calculate dates here. If the transaction below fails,
    # we still hold this `calculated_events` list so we can schedule the next run.
    training_where_time_list =
      from(twt in Oas.Trainings.TrainingWhereTime,
        left_join: tw in assoc(twt, :training_where),
        left_join: td in assoc(tw, :training_deleted),
        on: tw.id == td.training_where_id and td.when >= ^now,
        left_join: t in assoc(tw, :trainings),
        on: tw.id == t.training_where_id and t.when >= ^now,
        preload: [training_where: {tw, [trainings: t, training_deleted: td]}],
        where: twt.recurring == ^true
      )
      |> Oas.Repo.all()

    calculated_events = calculate_events(training_where_time_list, now_local)

    # --- STEP 2: WRITE (Inside Transaction) ---
    # We attempt to insert. We use try/rescue so that if a Race Condition (ConstraintError)
    # occurs, we simply log it and move on to scheduling.
    try do
      Oas.Repo.transaction(fn ->
        Enum.each(calculated_events, fn
          {:ok, {recurring_time, when1}} ->
            # Attempt to create the event
            maybe_create_event(recurring_time, when1)
          _ ->
            :ok
        end)
      end)
    rescue
      e ->
        Logger.warning("RecurringServer: DB Transaction failed (likely race condition), but rescheduling anyway. Error: #{inspect(e)}")
    catch
      :exit, _reason ->
        Logger.warning("RecurringServer: DB Transaction exited, rescheduling anyway.")
    end

    # --- STEP 3: SCHEDULE (Always Runs) ---
    # We use the list from Step 1, which exists regardless of Step 2's outcome.
    schedule_next_run(calculated_events, now_local)
  end

  @doc """
  For each recurring time, the date of the next training to create, given
  `now_local` (a `DateTime` in the society's time zone). Returns
  `{:ok, {recurring_time, date}}`, or `{:event_not_finished, {recurring_time, today}}`
  when today's session has not ended yet.
  """
  def calculate_events(training_where_time_list, %DateTime{} = now_local) do
    now = DateTime.to_date(now_local)
    now_time = DateTime.to_time(now_local)

    Enum.map(training_where_time_list, fn recurring_time ->
      case Integer.mod(recurring_time.day_of_week - Date.day_of_week(now), 7) do
        0 ->
          time_to_compare = recurring_time.end_time || recurring_time.start_time
          if Time.compare(now_time, time_to_compare) in [:gt, :eq] do
            {:ok, {recurring_time, Date.shift(now, day: 7)}}
          else
            {:event_not_finished, {recurring_time, now}}
          end

        d ->
          when1 = Date.shift(now, day: d)
          {:ok, {recurring_time, when1}}
      end
    end)
  end

  @doc """
  Milliseconds from `now_local` until the earliest event in `events` ends, at
  least 1000. nil if there are no events. The event's date and time are read
  in `now_local`'s time zone.
  """
  def next_run_ms([], _now_local), do: nil

  def next_run_ms(events, %DateTime{} = now_local) do
    {_, {recurring_time, when1}} =
      Enum.min_by(events, fn {_, {recurring_time, when1}} ->
        NaiveDateTime.new!(when1, recurring_time.end_time || recurring_time.start_time)
      end, NaiveDateTime)

    next_run =
      local_datetime(when1, recurring_time.end_time || recurring_time.start_time, now_local.time_zone)

    # Ensure we don't pass a negative number to send_after
    max(1000, DateTime.diff(next_run, now_local, :millisecond))
  end

  # A wall-clock time that falls in a spring-forward gap runs at the first
  # moment after the gap; one that happens twice in the autumn uses the
  # first occurrence.
  defp local_datetime(date, time, time_zone) do
    case DateTime.new(date, time, time_zone) do
      {:ok, dt} -> dt
      {:ambiguous, first, _second} -> first
      {:gap, _just_before, just_after} -> just_after
    end
  end

  defp schedule_next_run(events, now_local) do
    case next_run_ms(events, now_local) do
      nil -> nil
      ms -> Process.send_after(self(), :after_join, ms)
    end
  end

  def handle_info(:after_join, state) do
    if state.timer, do: Process.cancel_timer(state.timer)
    new_timer = check_and_create_recurring_events()
    {:noreply, %{state | timer: new_timer}}
  end

  def handle_cast(:rerun, state) do
    if state.timer, do: Process.cancel_timer(state.timer)
    new_timer = check_and_create_recurring_events()
    {:noreply, %{state | timer: new_timer}}
  end
end
