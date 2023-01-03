defmodule Oas.Config.Config do
  use Ecto.Schema
  import Ecto.Changeset

  schema "config_config" do
    field :token_expiry_days, :integer
    field :temporary_trainings, :integer
    timestamps()
  end
end
