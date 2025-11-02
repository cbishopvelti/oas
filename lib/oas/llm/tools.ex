defmodule Oas.Llm.Tools do

  defp get_authentication_tool do
    auth_tool = Function.new!(%{
      name: "Authentication tool",
      description: "If the user asks for their details, or anything that requires authentication and they're not authenticated, run this.",
      parameters_schema: %{
        type: "object",
        properties: %{
          # thing: %{
          #   type: "string",
          #   description: "The thing whose location is being requested."
          # }
        },
        # required: ["thing"]
      },
      function: fn _args, _context ->
        IO.puts("This Happened")
        {:ok, "You aren't authenticated to do that, try logging in: " <> "<a href=\"http://the_auth_server:4000/sign_in\">http://the_auth_server:4000/sign_in</a>"}
      end
    })
    auth_tool
  end

  def get_tools() do

    [
      get_authentication_tool()
    ]
  end
end
