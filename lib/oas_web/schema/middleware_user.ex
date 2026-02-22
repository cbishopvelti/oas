defmodule OasWeb.Schema.MiddlewareUser do
  @behaviour Absinthe.Middleware

  def call(resolution, _config) do
    case resolution.context do
      %{current_member: %{is_active: true}} ->
        resolution

      _ ->
        resolution
        |> Absinthe.Resolution.put_result({:error, "403 Forbidden"})
    end
  end
end
