defmodule Oas.Config.Config do
  use Ecto.Schema

  schema "config_config" do
    field :token_expiry_days, :integer
    field :temporary_trainings, :integer
    field :bacs, :string
    field :content, :string
    field :membership_terms, :string
    field :enable_booking, :boolean
    field :name, :string
    field :gocardless_enabled, :boolean
    field :gocardless_id, :string
    field :gocardless_key, :string
    field :gocardless_requisition_id, :string
    field :gocardless_account_id, :string
    field :credits, :boolean
    field :backup_recipient, :string

    # Society settings (multi-society Phase 2). The defaults for time_zone,
    # currency and phone_country_code live in the database, not here, because
    # an old migration inserts this struct before those columns exist.
    field :short_name, :string
    field :contact_email, :string
    field :time_zone, :string
    field :currency, :string
    field :phone_country_code, :string
    field :logo_url, :string
    field :primary_color, :string
    field :public_site_title, :string

    timestamps()
  end
end
