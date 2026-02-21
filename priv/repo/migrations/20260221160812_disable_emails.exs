defmodule Oas.Repo.Migrations.DisableEmails do
  use Ecto.Migration

  def change do
    alter table(:trainings) do
      add :disable_warning_emails, :boolean, null: true
    end
  end
end
