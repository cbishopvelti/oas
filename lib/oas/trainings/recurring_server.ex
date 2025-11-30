import Ecto.Query, only: [from: 2]

defmodule Oas.Trainings.RecurringServer do
  alias Oas.Trainings.RecurringServer
  use GenServer

  def start_link(init_args) do
    GenServer.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  def init(_init_args) do
    send(self(), :after_join)
    {:ok, %{
      timer: nil
    }}
  end

  def maybe_create_event(training_where, when1) do
    case training_where.trainings
      |> Enum.any?(fn (%{when: when2}) -> when1 == when2 end)
    do
      true -> nil # A training already exists on that date, so do nothing
      false ->
        %Oas.Trainings.Training{}
        |> Ecto.Changeset.cast(%{
          when: when1,
          notes: nil,
          commitment: false
        }, [:when, :notes, :commitment])
        |> Ecto.Changeset.put_assoc(:training_where, training_where)
        |> Oas.Repo.insert()
    end
    {:ok, when1}
  end
  # Oas.Trainings.RecurringServer.check_and_create_recurring_events()
  def check_and_create_recurring_events() do
    now = Date.utc_today()
    now_time = Time.utc_now()

    training_where_time = from(twt in Oas.Trainings.TrainingWhereTime,
      left_join: tw in assoc(twt, :training_where),
      left_join: t in assoc(tw, :trainings),
      on: tw.id == t.training_where_id and t.when >= ^now,
      preload: [training_where: {tw, trainings: t}],
      where: twt.recurring == ^true
    )
    |> Oas.Repo.all()
    |> Enum.map(fn (recurring_time) ->
      # rem(recurring_time.day_of_week, Date.day_of_week(now))
      case Integer.mod(recurring_time.day_of_week - Date.day_of_week(now), 7) do
        0 ->
          time_to_compare = recurring_time.end_time || recurring_time.start_time
          if (Time.compare(now_time, time_to_compare) == :gt or
            Time.compare(now_time, time_to_compare) == :eq
          ) do
            {:ok, {recurring_time, Date.shift(now, day: 7)}}
          else
            {:event_not_finished, {recurring_time, now}}
          end
        d ->
          when1 = Date.shift(now, day: d)
          # maybe_create_event(recurring_time.training_where, Date.shift(now, day: d))
          {:ok, {recurring_time, when1}}
      end
    end)


    {create_next_events, ignored_events} = training_where_time |> Enum.split_with(fn ({:ok, _}) -> true
      _ -> false
    end)

    # Create valid events
    create_next_events |> Enum.map(fn {:ok, {recurring_time, when1}} ->
      maybe_create_event(recurring_time.training_where, when1)
      {:ok, {recurring_time, when1}}
    end)

    # Trigger the next event
    create_next_events ++ ignored_events
    |> Enum.sort_by(fn {_, {recurring_time, when1}} ->
      time_to_compare = recurring_time.end_time || recurring_time.start_time
      NaiveDateTime.new!(when1, time_to_compare)
    end, {:asc, NaiveDateTime})
    |> List.first()
    |> then(fn nil -> nil
      {_, {recurring_time, when1}} ->
      time_to_compare = recurring_time.end_time || recurring_time.start_time
      next_run = NaiveDateTime.new!(when1, time_to_compare)
      now_dt = NaiveDateTime.utc_now()
      next_run_ms = NaiveDateTime.diff(next_run, now_dt, :millisecond)
      Process.send_after(self(), :after_join, next_run_ms)
    end)
  end

  def handle_info(:after_join, state) do
    IO.puts("304 RecurringServer :after_join")
    case Map.get(state, :timer, nil) do
      nil -> nil
      t -> Process.cancel_timer(t)
    end

    new_timer = check_and_create_recurring_events()

    {:noreply, %{timer: new_timer}}
  end

  def handle_cast(:rerun, state) do
    IO.puts("306 RecurringServer :rerun")
    case Map.get(state, :timer, nil) do
      nil -> nil
      t -> Process.cancel_timer(t)
    end

    new_timer = check_and_create_recurring_events()

    {:noreply, %{timer: new_timer}}
  end
end
