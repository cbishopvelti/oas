defmodule Oas.Llm.Tools do
alias LangChain.Function

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
        # {:ok, "Login in here: " <> "<a href=\"http://the_auth_server:4000/sign_in\">http://the_auth_server:4000/sign_in</a>"}
        {:ok, "Login " <> "[here](http://the_auth_server:4000/sign_in)"}
      end
    })
    auth_tool
  end

  def book_upcoming_event_tool do
    book_upcoming_event_tool = Function.new!(%{
      name: "Book event/jam/training",
      description: "Booking for upcoming event",
      parameters_schema: %{
        type: "object",
        properties: %{
          when: %{
            type: "string",
            description: "The date of the event to book the member onto. Format: YYYY-MM-dd"
          }
        },
        required: ["when"]
      },
      function: fn params, context ->
        IO.inspect(params, label: "501.1 params")
        IO.inspect(context, label: "501.2 context")
        {:ok, "Thank the user for booking"}
      end
    })
    book_upcoming_event_tool
  end

  def get_tools() do
    [
      get_authentication_tool(),
      book_upcoming_event_tool()
    ]
  end
end
