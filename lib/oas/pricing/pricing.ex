

defmodule Oas.Pricing.Pricing do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pricings" do
    field :name, :string
    field :blockly_conf, :map

    timestamps()
  end

  def changeset(pricing, attrs) do
    pricing
    |> cast(attrs, [:name, :blockly_conf])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
