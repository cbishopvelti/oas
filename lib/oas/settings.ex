defmodule Oas.Settings do
  @moduledoc """
  The single place that reads and writes the society settings tables:
  `config_config` (`Oas.Config.Config`), `config_llm` (`Oas.Config.ConfigLlm`)
  and `config_tokens` (`Oas.Config.Tokens`).

  Nothing outside this module should query those tables directly. There is no
  cache: every call goes to the database.
  """
  import Ecto.Query, only: [from: 2]

  alias Oas.Repo
  alias Oas.Config.{Config, ConfigLlm, Tokens}

  # ---- config_config ----

  @doc "The settings row, or nil if there is none."
  def get_config do
    from(c in Config, limit: 1) |> Repo.one()
  end

  @doc "The settings row. Raises if there is none."
  def get_config! do
    from(c in Config, limit: 1) |> Repo.one!()
  end

  @doc "One field of the settings row, or nil if there is no row."
  def get_config_value(key) when is_atom(key) do
    from(c in Config, limit: 1, select: field(c, ^key)) |> Repo.one()
  end

  @doc """
  Casts `attrs` onto the settings row, limited to `fields`, and saves it.

  Options:
    * `:empty_values` - passed to `Ecto.Changeset.cast/4`.
  """
  def update_config(attrs, fields, opts \\ []) do
    get_config()
    |> Ecto.Changeset.cast(attrs, fields, cast_opts(opts))
    |> Ecto.Changeset.validate_format(:backup_recipient, ~r/@/)
    |> Repo.update()
  end

  # ---- config_llm ----

  @doc "The LLM settings row, or nil if there is none."
  def get_llm do
    from(c in ConfigLlm, limit: 1) |> Repo.one()
  end

  @doc "The LLM settings row. Raises if there is none."
  def get_llm! do
    from(c in ConfigLlm, limit: 1) |> Repo.one!()
  end

  @doc "Casts `attrs` onto the LLM settings row, limited to `fields`, and saves it."
  def update_llm(attrs, fields, opts \\ []) do
    get_llm()
    |> Ecto.Changeset.cast(attrs, fields, cast_opts(opts))
    |> Repo.update()
  end

  # ---- config_tokens ----

  @doc "All token prices, ordered by `order_by` (default: quantity ascending)."
  def list_tokens(order_by \\ [asc: :quantity]) do
    from(t in Tokens, order_by: ^order_by) |> Repo.all()
  end

  @doc "The token price with the largest quantity not above `quantity`, or nil."
  def get_token_for_quantity(quantity) do
    from(t in Tokens,
      where: t.quantity <= ^quantity,
      order_by: [desc: t.quantity],
      limit: 1
    )
    |> Repo.one()
  end

  @doc "The cheapest token price. Raises if there are none."
  def get_min_token! do
    from(t in Tokens, order_by: [asc: :value], limit: 1) |> Repo.one!()
  end

  @doc "The lowest token value, or nil if there are none."
  def min_token_value do
    from(t in Tokens, select: min(t.value)) |> Repo.one()
  end

  @doc "The highest token value, or nil if there are none."
  def max_token_value do
    from(t in Tokens, select: max(t.value)) |> Repo.one()
  end

  def create_token(attrs) do
    %Tokens{}
    |> Ecto.Changeset.cast(attrs, [:quantity, :value])
    |> Repo.insert()
  end

  def delete_token!(id) do
    Repo.get!(Tokens, id) |> Repo.delete!()
  end

  defp cast_opts(opts), do: Keyword.take(opts, [:empty_values])
end
