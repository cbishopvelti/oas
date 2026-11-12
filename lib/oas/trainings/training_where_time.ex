defmodule Oas.Trainings.TrainingWhereTime do
  use Ecto.Schema
  import Ecto.Changeset


  schema "training_where_time" do
    belongs_to :training_where, Oas.Trainings.TrainingWhere
    field :day_of_week, :integer
    field :start_time, :time
    field :booking_offset, :string
    field :end_time, :time
    field :recurring, :boolean
    field :credit_amount, :decimal
    field :limit, :integer

    timestamps()
  end

  defp validate_booking_offset(changeset) do
    case get_field(changeset, :booking_offset) do
      nil -> changeset
      offset ->
        case Duration.from_iso8601(offset) do
          {:ok, _} -> changeset
          {:error, _} -> add_error(changeset, :booking_offset, "Invalid")
        end
    end
  end

  defp validate_recurring(changeset) do
    case {get_field(changeset, :day_of_week), get_field(changeset, :recurring)} do
      {nil, true} -> add_error(changeset, :recurring, "When day of week is not set, recurring can't be true")
      _ -> changeset
    end
  end

  def changeset(changeset, params \\ %{}) do
    # params = %{params | booking_offset: Duration.from_iso8601!(params.booking_offset)}
    changeset
    |> Ecto.Changeset.cast(params, [:day_of_week, :start_time, :booking_offset,
      :end_time, :recurring, :training_where_id, :credit_amount, :limit
    ], empty_values: [[], nil] ++ Ecto.Changeset.empty_values())
    |> validate_required([:start_time])
    |> validate_recurring()
    |> validate_booking_offset()
    |> Ecto.Changeset.unique_constraint([:day_of_week, :training_where_id])
  end

  def find_training_where_time(training, training_where_times) do
    training_where_time = training_where_times
    |> Enum.find(fn (%{day_of_week: day_of_week}) -> day_of_week == Date.day_of_week(training.when) end)
    case training_where_time do
      nil -> training_where_times |> Enum.find(fn (%{day_of_week: day_of_week}) -> is_nil(day_of_week) end)
      x -> x
    end
  end

  # Training dates/times are wall-clock times in the society's time zone
  # (Oas.Settings.time_zone/0), timestamps are naive UTC
  defp to_utc(%NaiveDateTime{} = naive), do: DateTime.from_naive!(naive, "Etc/UTC")
  defp to_utc(%DateTime{} = dt), do: DateTime.shift_zone!(dt, "Etc/UTC")

  defp local_to_utc(date, time) do
    case DateTime.new(date, time, Oas.Settings.time_zone()) do
      {:ok, dt} -> dt
      {:ambiguous, first, _second} -> first
      {:gap, _just_before, just_after} -> just_after
    end
    |> DateTime.shift_zone!("Etc/UTC")
  end

  def local_date(datetime) do
    datetime |> to_utc() |> DateTime.shift_zone!(Oas.Settings.time_zone()) |> DateTime.to_date()
  end

  def local_today(), do: Oas.Settings.today()

  def get_booking_cutoff_2(training, training_where_time) do
    training_where_time = training_where_time || %{}

    local_to_utc(training.when, training.start_time || Map.get(training_where_time, :start_time) || ~T[00:00:00])
    |> DateTime.shift(
      Duration.from_iso8601!(training.booking_offset || Map.get(training_where_time, :booking_offset) || "PT0H0M")
    )
  end

  # Returns a UTC DateTime. If booked within 60s of the cutoff, the cutoff is extended to 60s after booking.
  def get_booking_cutoff(inserted_at, training, training_where_time) do
    dt = get_booking_cutoff_2(training, training_where_time)
    case inserted_at do
      nil -> dt
      inserted_at ->
        inserted_at = to_utc(inserted_at)
        if DateTime.after?(inserted_at, DateTime.add(dt, -60)) do
          DateTime.add(inserted_at, 60)
        else
          dt
        end
    end
  end

  # Mirrors canUndo in the frontends
  def can_undo?(attendance, training, training_where_time, now \\ DateTime.utc_now()) do
    inserted_at = to_utc(attendance.inserted_at)
    booking_cutoff = get_booking_cutoff(attendance.inserted_at, training, training_where_time)

    before_cutoff = !training.commitment and DateTime.before?(now, booking_cutoff)
    within_grace = (local_date(inserted_at) == training.when or training.commitment == true) and
      DateTime.before?(now, DateTime.add(inserted_at, 60))

    before_cutoff or within_grace
  end
end
