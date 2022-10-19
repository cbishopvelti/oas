defmodule Oas.Trainings.Attendance do
  use Ecto.Schema
  import Ecto.Changeset

  schema "attendance" do
    belongs_to :training, Oas.Trainings.Training
    belongs_to :member, Oas.Members.Member
    has_one :token, Oas.Tokens.Token

    timestamps()
  end
end