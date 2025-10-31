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
  end

  object :user_bookings do
    field :id, :integer
    field :where, :string
    field :when, :string
    field :attendance_id, :integer
    field :inserted_by_member_id, :integer
    field :inserted_at, :string
    field :commitment, :boolean
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
          logout_link: Map.get(context, :logout_link, %{})
        }}
      end
    end

    field :user_bookings, list_of(:user_bookings) do
      resolve fn _, _, %{context: %{current_member: %{id: id}}} ->

        result = from(trai in Oas.Trainings.Training,
          left_join: atte in assoc(trai, :attendance), on: atte.training_id == trai.id and atte.member_id == ^id,
          left_join: memb in assoc(atte, :member),
          preload: [:training_where, attendance: {atte, [member: memb]}],
          where: trai.when >= ^Date.utc_today() and
          (memb.id == ^id or is_nil(memb.id)),
          order_by: [asc: trai.when, desc: trai.id]
        ) |> Oas.Repo.all
        |> Enum.map(fn booking ->
          %{
            id: Map.get(booking, :id),
            where: Map.get(booking, :training_where) |> Map.get(:name),
            when: Map.get(booking, :when),
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
            commitment: Map.get(booking, :commitment, nil)
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
            Oas.Attendance.add_attendance(
              %{training_id: training_id, member_id: member_id},
              %{inserted_by_member_id: member_id}
            )
          _ -> {:error, "Booking feature is not enabled"}
        end
      end
    end

    field :user_undo_attendance, :success do
      arg :attendance_id, non_null(:integer)
      resolve fn _, %{attendance_id: attendance_id}, %{context: %{current_member: %{id: member_id}}} ->
        config = from(c in Oas.Config.Config, select: c) |> Oas.Repo.one

        case config.enable_booking do
          true ->
            result = from(atte in Oas.Trainings.Attendance,
              join: trai in assoc(atte, :training),
              where: atte.id == ^attendance_id and
                atte.inserted_by_member_id == ^member_id and atte.member_id == ^member_id
                and (
                  ((is_nil(trai.commitment) or trai.commitment == false) and trai.when > ^Date.utc_today) or
                  (trai.when == ^Date.utc_today and atte.inserted_at < ^DateTime.add(DateTime.utc_now(), 60))
                )
            ) |> Oas.Repo.one

            case result do
              nil -> {:error, "Unable to undo"}
              %{id: id} ->
                Oas.Attendance.delete_attendance(%{attendance_id: id})

                IO.inspect(result, label: "109")
                {:ok, %{
                  success: true,
                  attendance_id: id,
                  training_id: result.training_id,
                  member_id: member_id
                }}
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
        IO.inspect(topic, label: "509.1")

        {:ok, topic: context |> Map.get(:context) |> Map.get(:current_member) |> Map.get(:id)}
      end

      trigger [
        :user_add_attendance, :user_undo_attendance,
        :add_attendance, :delete_attendance
      ], topic: fn attendance ->
        IO.inspect(attendance, label: "508")
        attendance.member_id
      end
    end
  end

end
