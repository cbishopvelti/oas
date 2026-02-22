import Ecto.Query, only: [from: 2]

defmodule Oas.Config.Tokens do
  use Ecto.Schema

  schema "config_tokens" do
    field :quantity, :integer
    field :value, :decimal
    timestamps()
  end

  def get_min_token do
    from(ct in Oas.Config.Tokens,
      order_by: [asc: :value],
      limit: 1
    )
    |> Oas.Repo.one!()
  end
end
