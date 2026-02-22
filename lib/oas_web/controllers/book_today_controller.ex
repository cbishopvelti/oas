import Ecto.Query, only: [from: 2]

defmodule OasWeb.BookTodayController do
  use OasWeb, :controller

  import OasWeb.MemberAuth
  plug :require_authenticated_member

  def get_one_training([], _now) do
    {:noevent, nil}
  end

  def get_one_training([training], _now) do
    {:ok, training}
  end

  def get_one_training(trainings, now) do
    distances =
      Enum.flat_map(trainings, fn %{start_time: start_time, end_time: end_time} = training ->
        [
          if(!is_nil(start_time),
            do: {DateTime.diff(now, start_time) |> abs(), training},
            else: nil
          ),
          if(!is_nil(end_time), do: {DateTime.diff(now, end_time) |> abs(), training}, else: nil)
        ]
      end)
      |> Enum.filter(fn
        nil -> false
        _ -> true
      end)

    case distances do
      [] ->
        {:tomany, nil}

      distances ->
        candidates =
          Enum.group_by(distances, fn {dist, _training} ->
            dist
          end)
          |> Enum.to_list()
          |> Enum.sort_by(fn {dist, _dist_train} -> dist end, :asc)
          |> List.first()

        case candidates do
          {_dist, [{_dist, training}]} ->
            {:ok, training}

          {_dist, dist_trainings} ->
            candidates =
              dist_trainings
              |> Enum.map(fn {_dist, training} ->
                training
              end)
              |> Enum.uniq()
              |> Enum.filter(fn %{start_time: start_time, end_time: end_time} ->
                DateTime.compare(start_time, now) in [:lt, :eq] and
                  DateTime.compare(end_time, now) in [:gt, :eq]
              end)

            case candidates do
              [one] -> {:ok, one}
              _ -> {:tomany, nil}
            end
        end
    end
  end

  def index(conn, _params) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    trainings =
      from(t in Oas.Trainings.Training,
        where: t.when == ^now
      )
      |> Oas.Repo.all()

    {status, training} = get_one_training(trainings, now)

    # training = try do
    #   from(t in Oas.Trainings.Training,
    #     where: t.when == ^now
    #   ) |> Oas.Repo.one()
    # rescue
    #   _e in Ecto.MultipleResultsError ->
    #     :tomany
    # end

    case {status, training} do
      {:tomany, _} ->
        conn
        |> put_flash(
          :error,
          "There is more than one event today. Please select your desired event from the booking page linked below."
        )
        |> render("index.html", %{
          public_url: Application.fetch_env!(:oas, :public_url)
        })

      {:noevent, _} ->
        conn
        |> put_flash(:error, "No events found today.")
        |> render("index.html", %{
          public_url: Application.fetch_env!(:oas, :public_url)
        })

      {:ok, training} ->
        member_id =
          OasWeb.MemberAuth.fetch_current_member(conn, [])
          |> Map.get(:assigns)
          |> Map.get(:current_member)
          |> Map.get(:id)

        try do
          {:ok,
           %{
             member_id: member_id,
             training_id: training_id
           }} =
            Oas.Attendance.add_attendance(
              %{training_id: training.id, member_id: member_id},
              %{inserted_by_member_id: member_id}
            )

          Absinthe.Subscription.publish(
            OasWeb.Endpoint,
            %{
              member_id: member_id,
              training_id: training_id
            },
            user_attendance_attendance: member_id,
            attendance_attendance: training_id
          )

          conn |> redirect(external: Application.fetch_env!(:oas, :public_url) <> "/bookings")
          # conn
          # |> put_flash(:error, "Debug only, remove")
          # |> render("index.html", %{
          #   public_url: Application.fetch_env!(:oas, :public_url)
          # })
        catch
          {:error, [%{message: "training_id: has already been taken", db_field: "training_id"}]} ->
            conn
            |> redirect(
              external:
                Application.fetch_env!(:oas, :public_url) <> "/bookings?error=already_booked"
            )

          {:error, [%{message: "limit: This training is full", db_field: _}]} ->
            conn
            |> redirect(
              external: Application.fetch_env!(:oas, :public_url) <> "/bookings?error-full=true"
            )

          {:error, errors} ->
            conn
            |> put_flash(
              :error,
              errors |> Enum.map(fn err -> err.message end) |> Enum.join("<br/>\n")
            )
            |> render("index.html", %{
              public_url: Application.fetch_env!(:oas, :public_url)
            })
        end
    end
  end
end
