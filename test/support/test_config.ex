defmodule Oas.TestConfig do
  @moduledoc """
  Test helper: casts `attrs` onto the config row, limited to `fields`, and
  saves it.
  """
  import Ecto.Query, only: [from: 2]

  def update_config(attrs, fields) do
    from(c in Oas.Config.Config, limit: 1)
    |> Oas.Repo.one!()
    |> Ecto.Changeset.cast(attrs, fields)
    |> Oas.Repo.update()
  end
end
