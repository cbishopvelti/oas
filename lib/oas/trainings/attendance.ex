defmodule Oas.Trainings.Attendance do
  use Ecto.Schema
  import Ecto.Changeset

  schema "attendance" do
    belongs_to :training, Oas.Trainings.Training
    belongs_to :member, Oas.Members.Member
    has_one :token, Oas.Tokens.Token

    belongs_to :inserted_by, Oas.Members.Member, foreign_key: :inserted_by_member_id

    field :undo_until, :utc_datetime

    timestamps()
  end
end