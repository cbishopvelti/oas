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
  The society's name, for emails and file names. Falls back to "OAS" when the
  name is blank or there is no settings row.
  """
  def society_name do
    case get_config_value(:name) do
      name when is_binary(name) ->
        case String.trim(name) do
          "" -> "OAS"
          trimmed -> trimmed
        end

      _ ->
        "OAS"
    end
  end

  @doc """
  The society's name made safe for a file name: lower case, with runs of
  anything other than letters and digits turned into a single `-`. Falls back
  to "oas".
  """
  def society_slug do
    society_name()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
    |> case do
      "" -> "oas"
      slug -> slug
    end
  end

  @doc """
  Casts `attrs` onto the settings row, limited to `fields`, validates it and
  saves it.

  Validation (only on fields that change): the backup recipient and contact
  email contain an `@`; the time zone exists in the time zone database; the
  currency is a three-letter ISO 4217 style code such as `GBP`; the phone
  country code is 1 to 4 digits with no `+`; the primary colour is a hex
  colour such as `#1a2b3c` or `#abc`. The time zone, currency and phone
  country code cannot be blank.

  Options:
    * `:empty_values` - passed to `Ecto.Changeset.cast/4`.
  """
  def update_config(attrs, fields, opts \\ []) do
    get_config()
    |> Ecto.Changeset.cast(attrs, fields, cast_opts(opts))
    |> validate_config()
    |> Repo.update()
  end

  defp validate_config(changeset) do
    import Ecto.Changeset

    changeset
    |> validate_format(:backup_recipient, ~r/@/)
    |> validate_format(:contact_email, ~r/^[^\s@]+@[^\s@]+$/)
    |> validate_not_blank([:time_zone, :currency, :phone_country_code, :bank_country])
    |> validate_change(:time_zone, fn :time_zone, tz ->
      if valid_time_zone?(tz), do: [], else: [time_zone: "is not a known time zone"]
    end)
    |> validate_format(:currency, ~r/^[A-Z]{3}$/,
      message: "must be a three-letter code such as GBP"
    )
    |> validate_format(:phone_country_code, ~r/^[0-9]{1,4}$/,
      message: "must be 1 to 4 digits, without a +"
    )
    |> validate_format(:bank_country, ~r/^[A-Z]{2}$/,
      message: "must be a two-letter country code such as GB"
    )
    |> validate_format(:primary_color, ~r/^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/,
      message: "must be a hex colour such as #1a2b3c"
    )
  end

  # Casting "" gives nil, which would otherwise slip past the format checks
  # and fail on the NOT NULL column.
  defp validate_not_blank(changeset, fields) do
    Enum.reduce(fields, changeset, fn f, cs ->
      if Map.has_key?(cs.changes, f) and is_nil(Map.get(cs.changes, f)) do
        Ecto.Changeset.add_error(cs, f, "can't be blank", validation: :required)
      else
        cs
      end
    end)
  end

  @doc "True if `tz` is a time zone the configured time zone database knows."
  def valid_time_zone?(tz) when is_binary(tz) do
    match?({:ok, _}, DateTime.now(tz))
  end

  def valid_time_zone?(_), do: false

  @default_time_zone "Europe/London"

  @doc """
  The society's time zone, such as `"Europe/London"`. Falls back to
  `"Europe/London"` if there is no settings row.
  """
  def time_zone do
    get_config_value(:time_zone) || @default_time_zone
  end

  @doc """
  Today's date in the society's time zone. Pass a UTC `DateTime` to get the
  society's date at that instant instead of now.
  """
  def today(utc \\ utc_now()), do: now(utc) |> DateTime.to_date()

  @doc """
  The current time in the society's time zone. Pass a UTC `DateTime` to get
  that instant in the society's time zone instead of now.
  """
  def now(utc \\ utc_now()), do: DateTime.shift_zone!(utc, time_zone())

  # Tests can pin the clock for the calling process with
  # `Oas.Settings.put_test_utc_now/1`. The override is compiled out of every
  # other environment.
  if Application.compile_env(:oas, :test_clock, false) do
    defp utc_now, do: Process.get(:oas_test_utc_now) || DateTime.utc_now()

    @doc false
    def put_test_utc_now(nil), do: Process.delete(:oas_test_utc_now)
    def put_test_utc_now(%DateTime{} = utc), do: Process.put(:oas_test_utc_now, utc)
  else
    defp utc_now, do: DateTime.utc_now()
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
