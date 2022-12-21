import Ecto.Query, only: [from: 2]
defmodule OasWeb.Schema.SchemaUser do
  use Absinthe.Schema.Notation

  object :user do
    field :id, :integer
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
    field :inserted_at, :string
    field :undo_until, :string
  end

  object :user_queries do
    field :user, :user do
      resolve fn _, _, conn -> 
        %{context: context} = conn

        {:ok, %{
          id: Map.get(context, :current_member, %{}) |> Map.get(:id),
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
          (memb.id == ^id or is_nil(memb.id)),
          order_by: [desc: trai.when, desc: trai.id]
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
            undo_until: Map.get(booking, :attendance, [])
              |> List.first
              |> case do
                nil -> nil
                x -> Map.get(x, :undo_until)
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
        Oas.Attendance.add_attendance(
          %{training_id: training_id, member_id: member_id},
          %{inserted_by_member_id: member_id}
        )
      end
    end
  end
end
