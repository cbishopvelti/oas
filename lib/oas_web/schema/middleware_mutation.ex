defmodule OasWeb.Schema.MiddlewareMutation do
  @behaviour Absinthe.Middleware

  def call(resolution, _config) do
    case resolution.context do
      %{current_member: %{is_admin: true}} ->
        resolution
      _ ->
        resolution
        |> Absinthe.Resolution.put_result({:error, "403 Forbidden, you are not an admin; you can't do that"})
    end
  end
end