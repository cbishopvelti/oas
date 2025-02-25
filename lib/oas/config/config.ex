defmodule Oas.Config.Config do
  use Ecto.Schema

  schema "config_config" do
    field :token_expiry_days, :integer
    field :temporary_trainings, :integer
    field :bacs, :string
    field :enable_booking, :boolean
    field :name, :string
    field :gocardless_id, :string
    field :gocardless_key, :string
    field :gocardless_requisition_id, :string
    field :gocardless_account_id, :string
    field :credits, :boolean
    timestamps()
  end
end
