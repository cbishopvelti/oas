defmodule OasWeb.LayoutView do
  use OasWeb, :view

  # Phoenix LiveDashboard is available only in development by default,
  # so we instruct Elixir to not warn if the dashboard route is missing.
  @compile {:no_warn_undefined, {Routes, :live_dashboard_path, 2}}

  @doc """
  The society's name, logo and primary colour, as set by
  `OasWeb.SocietyBranding`. Falls back to the default "OAS" look when the
  plug has not run.
  """
  def branding(assigns), do: assigns[:branding] || OasWeb.SocietyBranding.default()
end
