import Ecto.Query, only: [from: 2]
defmodule OasWeb.Schema.SchemaUser do
  use Absinthe.Schema.Notation

  object :user do
    field :name, :string
    field :email, :string
    field :logout_link, :string
  end
  
  object :user_bookings do
    field :id, :integer
    field :where, :string
    field :when, :string
    field :attendance_id, :integer
    field :inserted_by_member_id, :integer
    field :booked_at, :string
  end

  object :user_queries do
    field :user, :user do
      resolve fn _, _, conn -> 
        %{context: context} = conn

        {:ok, %{
          name: Map.get(context, :current_member, %{}) |> Map.get(:name),
          email: Map.get(context, :current_member, %{}) |> Map.get(:email),
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
          (memb.id == ^id or is_nil(memb.id))
        ) |> Oas.Repo.all
        |> Enum.map(fn booking ->
          IO.inspect(booking)
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
            booked_at: Map.get(booking, :inserted_at, nil),
            inserted_by_member_id: Map.get(booking, :inserted_by, %{}) |> Map.get(:id)
          }
        end)

        IO.puts("001")
        IO.inspect(result)

        {:ok, result}
      end
    end
  end

  object :user_mutations do
    field :user_add_attendance, :success do
      arg :training_id, non_null(:integer)
      resolve fn _, %{training_id: training_id}, %{context: %{current_member: %{id: member_id}}} ->
        Oas.Attendance.add_attendance(
          %{training_id: training_id, member_id: member_id},
          %{inserted_by_member_id: member_id}
        )
      end
    end
  end
end
