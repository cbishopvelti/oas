defmodule Oas.Repo.Migrations.BookingQueue do
  use Ecto.Migration

  def change do

    alter table(:training_where) do
      add :time, :time_usec
      add :cutoff_booking, :duration
      add :cutoff_queue, :duration
      add :max_attendees, :integer
    end
  end
end
