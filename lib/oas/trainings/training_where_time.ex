defmodule Oas.Trainings.TrainingWhereTime do
  use Ecto.Schema
  import Ecto.Changeset


  schema "training_where_time" do
    belongs_to :training_where, Oas.Tranings.TrainingWhere
    field :day_of_week, :integer
    field :start_time, :time
    field :booking_offset, :string
    field :end_time, :time
    field :recurring, :boolean

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
      :end_time, :recurring, :training_where_id
    ])
    |> validate_required([:start_time])
    |> validate_recurring()
    |> validate_booking_offset()
    |> Ecto.Changeset.unique_constraint([:day_of_week, :training_where_id])
  end
end
