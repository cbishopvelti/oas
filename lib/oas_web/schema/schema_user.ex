import Ecto.Query, only: [from: 2]
defmodule OasWeb.Schema.SchemaUser do
  use Absinthe.Schema.Notation

  object :user do
    field :id, :integer
    field :name, :string
    field :email, :string
    field :is_admin, :boolean
    field :is_reviewer, :boolean
    field :logout_link, :string
    field :membership_status, :member_status
  end

  object :user_bookings do
    field :id, :integer
    field :where, :string
    field :when, :string
    field :start_time, :string
    field :booking_cutoff, :string
    field :attendance_id, :integer
    field :inserted_by_member_id, :integer
    field :inserted_at, :string
    field :commitment, :boolean
    field :full, :boolean
  end

  object :user_queries do
    field :user, :user do
      resolve fn _, _, conn ->
        %{context: context} = conn

        {:ok, %{
          id: Map.get(context, :current_member, %{}) |> Map.get(:id),
          name: Map.get(context, :current_member, %{}) |> Map.get(:name),
          email: Map.get(context, :current_member, %{}) |> Map.get(:email),
          is_admin: Map.get(context, :current_member, %{}) |> Map.get(:is_admin),
          is_reviewer: Map.get(context, :current_member, %{}) |> Map.get(:is_reviewer),
          membership_status: Oas.Attendance.check_membership(Map.get(context, :current_member, %{})) |> elem(1),
          logout_link: Map.get(context, :logout_link, %{})
        }}
      end
    end

    field :user_bookings, list_of(:user_bookings) do
      resolve fn _, _, %{context: %{current_member: %{id: id}}} ->

        attendance_counts =
          from a in Oas.Trainings.Attendance,
            group_by: a.training_id,
            select: %{training_id: a.training_id, count: count(a.id)}

        result = from(trai in Oas.Trainings.Training,
          left_join: atte in assoc(trai, :attendance), on: atte.training_id == trai.id and atte.member_id == ^id,
          left_join: memb in assoc(atte, :member),
          left_join: ac in subquery(attendance_counts), on: ac.training_id == trai.id,
          preload: [training_where: [:training_where_time], attendance: {atte, [member: memb]}],
          where: trai.when >= ^Date.utc_today() and
          (memb.id == ^id or is_nil(memb.id)),
          order_by: [asc: trai.when, desc: trai.id],

          select: {trai, coalesce(ac.count, 0)}
        ) |> Oas.Repo.all
        |> Enum.map(fn {booking, limit} ->
          training_where_time = Oas.Trainings.TrainingWhereTime.find_training_where_time(booking, booking.training_where.training_where_time)

          %{
            id: Map.get(booking, :id),
            where: Map.get(booking, :training_where) |> Map.get(:name),
            when: Map.get(booking, :when),
            start_time: Map.get(training_where_time || %{}, :start_time, nil),
            booking_cutoff: Oas.Trainings.TrainingWhereTime.get_booking_cutoff(Map.get(booking, :attendance, []) |> List.first() |> case do
              nil -> nil
              x -> Map.get(x, :inserted_at)
            end, booking, training_where_time),
            attendance_id: Map.get(booking, :attendance, [])
              |> List.first
              |> case do
                nil -> nil
                x -> Map.get(x, :id)
              end,
            inserted_by_member_id: Map.get(booking, :attendance, [])
              |> List.first
              |> case do
                nil -> nil
                x -> Map.get(x, :inserted_by_member_id)
              end,
            inserted_at: Map.get(booking, :attendance, [])
              |> List.first
              |> case do
                nil -> nil
                x -> Map.get(x, :inserted_at)
              end,
            commitment: Map.get(booking, :commitment, nil),
            full: case Map.get(booking, :limit) do
              nil -> false
              tr_limit -> limit >= tr_limit
            end
          }
        end)

        {:ok, result}
      end
    end
  end

  object :user_mutations do
    field :user_add_attendance, :success do
      arg :training_id, non_null(:integer)
      resolve fn _, %{training_id: training_id}, %{context: %{current_member: %{id: member_id}}} ->
        config = from(c in Oas.Config.Config, select: c) |> Oas.Repo.one

        case config.enable_booking do
          true ->
            try do
              Oas.Attendance.add_attendance(
                %{training_id: training_id, member_id: member_id},
                %{inserted_by_member_id: member_id}
              )
            catch
              error -> error
            end
          _ -> {:error, "Booking feature is not enabled"}
        end
      end
    end

    field :user_undo_attendance, :success do
      arg :attendance_id, non_null(:integer)
      resolve fn _, %{attendance_id: attendance_id}, %{context: %{current_member: %{id: member_id}}} ->
        config = from(c in Oas.Config.Config, select: c) |> Oas.Repo.one
        now = DateTime.utc_now()

        case config.enable_booking do
          true ->
            result = from(atte in Oas.Trainings.Attendance,
              join: trai in assoc(atte, :training),
              preload: [training: [training_where: [:training_where_time]]],
              where: atte.id == ^attendance_id and
                atte.inserted_by_member_id == ^member_id and atte.member_id == ^member_id
                and (
                  ((is_nil(trai.commitment) or trai.commitment == false) and trai.when >= ^Date.utc_today)
                  or (trai.when == ^Date.utc_today and atte.inserted_at < ^DateTime.add(now, 60))
                )
            ) |> Oas.Repo.one

            booking_cutoff = Oas.Trainings.TrainingWhereTime.get_booking_cutoff(
              result.inserted_at,
              result.training,
              Oas.Trainings.TrainingWhereTime.find_training_where_time(
                result.training,
                result.training.training_where.training_where_time
              )
            )

            case result do
              nil -> {:error, "Unable to undo"}
              %{
                id: id,
                inserted_at: inserted_at
              } ->
                if (
                  NaiveDateTime.compare(inserted_at, booking_cutoff) == :lt  or NaiveDateTime.compare(inserted_at, booking_cutoff) == :eq or
                  NaiveDateTime.compare(inserted_at, NaiveDateTime.shift(now, minute: 1)) == :lt or NaiveDateTime.compare(inserted_at, NaiveDateTime.shift(now, minute: 1)) == :eq
                ) do
                  Oas.Attendance.delete_attendance(%{attendance_id: id})
                  {:ok, %{
                    success: true,
                    attendance_id: id,
                    training_id: result.training_id,
                    member_id: member_id
                  }}
                else
                  {:error, "Unable to undo due to being past the booking cutoff of over 1 minute"}
                end
            end
          _ -> {:error, "Booking feature is not enabled"}
        end

      end
    end
  end

  object :user_subscriptions do
    field :user_attendance_attendance, :success do
      config fn _args, context ->
        # IO.inspect(context, label: "509 context")
        topic = context |> Map.get(:context) |> Map.get(:current_member) |> Map.get(:id)

        {:ok, topic: [context |> Map.get(:context) |> Map.get(:current_member) |> Map.get(:id), "global"]}
      end

      trigger [
        :user_add_attendance, :user_undo_attendance,
        :add_attendance, :delete_attendance
      ], topic: fn attendance ->
        IO.inspect(attendance, label: "508 subscription user_attendance_attendance")
        attendance.member_id
      end
    end
  end

end
