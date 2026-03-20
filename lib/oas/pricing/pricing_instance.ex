

defmodule Oas.Pricing.PricingInstance do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pricing_instances" do
    field :name, :string
    field :is_active, :boolean
    field :blockly_conf, :map

    belongs_to :pricing, Oas.Pricing.PricingInstance

    timestamps()
  end

  def changeset(pricing, attrs) do
    pricing
    |> cast(attrs, [:name, :blockly_conf, :is_active, :pricing_id])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
