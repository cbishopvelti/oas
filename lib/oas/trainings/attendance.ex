defmodule Oas.Trainings.Attendance do
  use Ecto.Schema
  import Ecto.Changeset

  schema "attendance" do
    belongs_to :training, Oas.Trainings.Training
    belongs_to :member, Oas.Members.Member
    has_one :token, Oas.Tokens.Token

    belongs_to :inserted_by, Oas.Members.Member, foreign_key: :inserted_by_member_id

    has_one :credit, Oas.Credits.Credit, foreign_key: :attendance_id

    timestamps()
  end


  def validate_limit(changeset, %{limit: nil}, _inserted_by_member) do
    changeset
  end
  def validate_limit(changeset, _training, %{is_admin: true}) do
    changeset
  end
  def validate_limit(changeset, training, _inserted_by_member) do
    case (training.attendance |> length) >= training.limit do
      true -> add_error(changeset, :limit, "This training is full", id: training.id)
      false -> changeset
    end
  end

  # Publishes when adding an attendance has filled the training. Call it after the
  # attendance is committed, with the training as it was loaded before the insert.
  def maybe_publish_full(%{limit: nil}) do
    :ok
  end
  def maybe_publish_full(training) do
    case (training.attendance |> length) >= (training.limit - 1) do
      true -> Absinthe.Subscription.publish(OasWeb.Endpoint, %{success: true}, user_attendance_attendance: "global")
      false -> :ok
    end
  end

  def maybe_publish_spaces(%{limit: nil}) do
    :ok
  end
  def maybe_publish_spaces(%{limit: limit, attendance: attendance}) do
    case (attendance |> length) <= limit do # This is using data before the delete, so <=
      true -> Absinthe.Subscription.publish(OasWeb.Endpoint, %{success: true}, user_attendance_attendance: "global")
      false -> :ok
    end
  end

end
