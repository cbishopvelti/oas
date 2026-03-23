

defmodule Oas.Pricing.PricingInstance do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pricing_instances" do
    field :name, :string
    field :is_active, :boolean
    field :blockly_conf, :map
    field :blockly_lua, :string

    belongs_to :pricing, Oas.Pricing.Pricing
    has_many :trainings, Oas.Trainings.Training

    timestamps()
  end

  def changeset(pricing, attrs) do
    pricing
    |> cast(attrs, [:name, :blockly_conf, :blockly_lua, :is_active, :pricing_id])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
