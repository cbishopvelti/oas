import Ecto.Query, only: [from: 2]

defmodule Oas.Things.Thing do
  use Ecto.Schema
  import Ecto.Changeset

  schema "things" do
    field :what, :string
    field :value, :decimal
    field :when, :date

    has_many :credits, Oas.Credits.Credit, foreign_key: :thing_id
  end
end
