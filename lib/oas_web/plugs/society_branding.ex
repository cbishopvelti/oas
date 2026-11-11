defmodule OasWeb.SocietyBranding do
  @moduledoc """
  Reads the society's name, logo and primary colour from `Oas.Settings` once
  per request and puts them in `conn.assigns.branding`, for the root layout.

  `name` falls back to "OAS". `logo_url` and `primary_color` are nil when
  unset (or blank), and the layout then keeps its default look. The colour is
  checked again here because it goes into a `<style>` block.
  """
  import Plug.Conn

  @hex_color ~r/^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/

  def init(opts), do: opts

  def call(conn, _opts) do
    assign(conn, :branding, branding())
  end

  def branding do
    config = Oas.Settings.get_config()

    %{
      name: Oas.Settings.society_name(),
      logo_url: config && blank_to_nil(config.logo_url),
      primary_color: config && valid_color(config.primary_color)
    }
  end

  @doc "The branding to use when the plug has not run (e.g. error pages)."
  def default, do: %{name: "OAS", logo_url: nil, primary_color: nil}

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(_), do: nil

  defp valid_color(value) when is_binary(value) do
    value = String.trim(value)
    if Regex.match?(@hex_color, value), do: value, else: nil
  end

  defp valid_color(_), do: nil
end
