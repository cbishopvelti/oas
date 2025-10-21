defmodule Oas.Trainings.Attendance do
  use Ecto.Schema

  schema "attendance" do
    belongs_to :training, Oas.Trainings.Training
    belongs_to :member, Oas.Members.Member
    has_one :token, Oas.Tokens.Token

    belongs_to :inserted_by, Oas.Members.Member, foreign_key: :inserted_by_member_id

    has_one :credit, Oas.Credits.Credit, foreign_key: :attendance_id

    timestamps()
  end
end
