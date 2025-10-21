
defmodule Oas.Things.Thing do
  use Ecto.Schema

  schema "things" do
    field :what, :string
    field :value, :decimal
    field :when, :date

    has_many :credits, Oas.Credits.Credit, foreign_key: :thing_id

    timestamps()
  end
end
