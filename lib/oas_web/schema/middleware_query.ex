defmodule OasWeb.Schema.MiddlewareQuery do
  @behaviour Absinthe.Middleware

  def call(resolution, _config) do
    case resolution.context do
      %{current_member: %{is_reviewer: is_reviewer, is_admin: is_admin}} when (is_reviewer == true or is_admin == true) ->
        resolution
      _ ->
        IO.puts("OasWeb.Schema.MiddlewareQuery, UNAUTHORIZED")
        resolution
        |> Absinthe.Resolution.put_result({:error, "403 Forbidden, get lost"})
    end
  end
end
