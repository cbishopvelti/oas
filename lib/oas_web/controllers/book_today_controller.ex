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
      e in Ecto.MultipleResultsError -> IO.inspect(e, label: "005")
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
        |> put_flash(:error, "No events found today")
        |> render("index.html", %{
          public_url: Application.fetch_env!(:oas, :public_url)
        })
      training ->
        session = get_session(conn)

        conn |> Plug.Conn.send_resp(200, "Success")
    end
  end
end
