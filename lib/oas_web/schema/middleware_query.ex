defmodule OasWeb.Schema.MiddlewareQuery do
  @behaviour Absinthe.Middleware

  def call(resolution, _config) do
    # IO.inspect(resolution.context, label: "101")
    case resolution.context do
      %{current_member: %{is_reviewer: is_reviewer, is_admin: is_admin}} when (is_reviewer == true or is_admin == true) ->
        resolution
      _ ->
        IO.puts("should not happen")
        resolution
        |> Absinthe.Resolution.put_result({:error, "403 Forbidden, get lost"})
    end
  end
end
