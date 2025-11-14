import Ecto.Query, only: [from: 2]

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
      name: "Book jam/training",
      description: "Booking for upcoming jams and trainings",
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
        case context.member |> Map.get(:id) do
          nil ->
            {:error, "Unauthorized, login " <> "[here](#{ Phoenix.VerifiedRoutes.unverified_url(OasWeb.Endpoint, OasWeb.Router.Helpers.member_session_path(OasWeb.Endpoint, :new)) })"}
          member_id ->
            case from(t in Oas.Trainings.Training,
                preload: [:training_where],
                where: t.when == ^params["when"]
              ) |> Oas.Repo.one()
            do
              nil -> {:error, "Error finding event/traning/jam to add you to."}
              event -> # Oas.Attendance.add_attendance(%{member_id: 1, training_id: 267},%{inserted_by_member_id: 1})
                try do
                  {:ok, _attendance} = Oas.Attendance.add_attendance(
                    %{member_id: member_id, training_id: event.id},
                    %{inserted_by_member_id: member_id}
                  )
                  # Absinthe.Subscription.publish(OasWeb.Endpoint, %{success: true}, user_attendance_attendance: 139)
                  Absinthe.Subscription.publish(OasWeb.Endpoint, %{success: true}, user_attendance_attendance: member_id)
                  Absinthe.Subscription.publish(OasWeb.Endpoint, %{id: event.id}, attendance_attendance: event.id)

                  {:ok, "Added to event"}
                catch
                  {:error, [%{message: "training_id: has already been taken"} | _]} ->
                    {:error, "The user is already booked in to the jam/training. Tell the user they're already booked in."}
                  {:error, _} -> {:error, "An error occurred"}
                end
            end
        end
      end
    })
    book_upcoming_event_tool
  end

  defp upcoming_trainings(id) do
    # 1. Start with the base query to get all future trainings.
    base_query =
      from(trai in Oas.Trainings.Training,
        where: trai.when >= ^Date.utc_today(),
        order_by: [asc: trai.when, desc: trai.id]
      )

    # 2. Conditionally join and preload the user's attendance ONLY if an id is provided.
    if id do
      # When an ID is present, we join on that specific member's attendance.
      from([trai] in base_query,
        left_join: atte in assoc(trai, :attendance),
          on: atte.member_id == ^id,
        left_join: memb in assoc(atte, :member),
        preload: [:training_where, attendance: {atte, [member: memb]}]
      )
    else
      # When ID is nil, we don't need to find a specific user.
      # We can just preload all associations as needed without the complex join.
      # If you wanted to load ALL attendances for all trainings, you would do it here.
      # For this case, we just preload the training_where.
      from(trai in base_query,
        preload: [:training_where]
      )
    end
  end
  def get_upcoming_events_tool do
    Function.new!(%{
      name: "Upcoming jams/trainings",
      description: "Get upcoming jams and trainings",
      parameters_schema: %{
        type: "object",
        properties: %{
        },
      },
      function: fn _, context ->
        id = context.member |> Map.get(:id)
        out = upcoming_trainings(id)
        |> Oas.Repo.all
        |> Enum.map(fn booking ->
          attending = Map.get(booking, :attendance, [])
            |> case do
              [x | _] -> "User is attending this event"
              _ -> "User is not attending this event"
            end

          "#{Map.get(booking, :when)}, #{Map.get(booking, :training_where) |> Map.get(:name)}, #{attending}"
        end) |> Enum.join("\n")
        IO.inspect(out, label: "Upcoming Events")
        {:ok, "These are are in addition to and override the events you already know about: \n" <>out}
      end
    })
  end

  def get_credits do
  Function.new!(%{
    name: "Get credits",
    description: "Get users credits",
    parameters_schema: %{
      type: "object",
      properties: %{
      },
    },
    function: fn _, context ->
      case context.member |> Map.get(:id) do
        nil ->
          {:error, "Unauthorized, login " <> "[here](#{ Phoenix.VerifiedRoutes.unverified_url(OasWeb.Endpoint, OasWeb.Router.Helpers.member_session_path(OasWeb.Endpoint, :new)) })"}
        member_id ->
          {_, total} = Oas.Credits.Credit2.get_credit_amount(%{member_id: member_id})
          {:ok, "The user has : " <> (total |> Decimal.to_string()) <> " credits."}
      end
    end
    })
  end

  def get_tools() do
    [
      # get_authentication_tool(),
      book_upcoming_event_tool(),
      get_upcoming_events_tool(),
      get_credits()
    ]
  end
end
