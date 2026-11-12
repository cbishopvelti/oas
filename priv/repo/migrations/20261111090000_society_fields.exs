defmodule Oas.Repo.Migrations.SocietyFields do
  use Ecto.Migration

  def change do
    alter table(:config_config) do
      add :short_name, :string, null: true
      add :contact_email, :string, null: true
      add :time_zone, :string, null: false, default: "Europe/London"
      add :currency, :string, null: false, default: "GBP"
      add :phone_country_code, :string, null: false, default: "44"
      add :logo_url, :string, null: true
      add :primary_color, :string, null: true
      add :public_site_title, :string, null: true
    end
  end
end
