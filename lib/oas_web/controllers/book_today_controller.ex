import Ecto.Query, only: [from: 2]

defmodule OasWeb.BookTodayController do
  use OasWeb, :controller

  import OasWeb.MemberAuth
  plug :require_authenticated_member

  def index(conn, _params) do

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    training = try do
      from(t in Oas.Trainings.Training,
        where: t.when == ^now
      ) |> Oas.Repo.one()
    rescue
      _e in Ecto.MultipleResultsError ->
        :tomany
    end

    case training do
      :tomany ->
        conn
        |> put_flash(:error, "There is more than one event today.")
        |> render("index.html", %{
          public_url: Application.fetch_env!(:oas, :public_url)
        })
      nil ->
        conn
        |> put_flash(:error, "No events found today.")
        |> render("index.html", %{
          public_url: Application.fetch_env!(:oas, :public_url)
        })
      training ->
        member_id = OasWeb.MemberAuth.fetch_current_member(conn, [])
          |> Map.get(:assigns)
          |> Map.get(:current_member)
          |> Map.get(:id)

        try do
          {:ok, %{
            member_id: member_id,
            training_id: training_id
          } } = Oas.Attendance.add_attendance(
            %{training_id: training.id, member_id: member_id},
            %{inserted_by_member_id: member_id}
          )

          Absinthe.Subscription.publish(OasWeb.Endpoint, %{
            member_id: member_id,
            training_id: training_id
          },
          [
            user_attendance_attendance: member_id,
            attendance_attendance: training_id
          ])

          conn |> redirect(external: Application.fetch_env!(:oas, :public_url) <> "/bookings")
          # conn
          # |> put_flash(:error, "Debug only, remove")
          # |> render("index.html", %{
          #   public_url: Application.fetch_env!(:oas, :public_url)
          # })
        catch
          {:error, [%{message: "training_id: has already been taken", db_field: "training_id"}]} ->
            conn |> redirect(external: Application.fetch_env!(:oas, :public_url) <> "/bookings?error=already_booked")
          {:error, [%{message: "limit: This training is full", db_field: _}]} ->
            conn |> redirect(external: Application.fetch_env!(:oas, :public_url) <> "/bookings?error-full=true")
          {:error, errors} ->
            conn
            |> put_flash(:error, errors |> Enum.map(fn (err) -> err.message end) |> Enum.join("<br/>\n"))
            |> render("index.html", %{
              public_url: Application.fetch_env!(:oas, :public_url)
            })
        end
    end
  end
end
