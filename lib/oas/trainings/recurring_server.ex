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
            Map.get(training_where, :limit)
        }, [:when, :notes, :commitment])
        |> Ecto.Changeset.put_assoc(:training_where, training_where)
        |> Oas.Repo.insert() # This might raise if a DB Unique Index is hit
    end
  end

  # Oas.Trainings.RecurringServer.check_and_create_recurring_events()
  def check_and_create_recurring_events() do
    now = Date.utc_today()
    now_time = Time.utc_now()

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

    calculated_events =
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
    schedule_next_run(calculated_events)
  end

  defp schedule_next_run(events) do
    events
    |> Enum.sort_by(fn {_, {recurring_time, when1}} ->
      time_to_compare = recurring_time.end_time || recurring_time.start_time
      NaiveDateTime.new!(when1, time_to_compare)
    end, {:asc, NaiveDateTime})
    |> List.first()
    |> case do
      nil ->
        nil

      {_, {recurring_time, when1}} ->
        time_to_compare = recurring_time.end_time || recurring_time.start_time
        next_run = NaiveDateTime.new!(when1, time_to_compare)
        now_dt = NaiveDateTime.utc_now()

        # Ensure we don't pass a negative number to send_after
        next_run_ms = max(1000, NaiveDateTime.diff(next_run, now_dt, :millisecond))

        Process.send_after(self(), :after_join, next_run_ms)
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
