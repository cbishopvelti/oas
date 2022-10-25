import Ecto.Query, only: [from: 2, where: 3]

defmodule OasWeb.Schema.SchemaAttendance do
  use Absinthe.Schema.Notation

  object :memberAttendance do
    field :id, :integer
    field :attendance_id, :integer
    field :name, :string
    field :email, :string
    field :tokens, :integer
    field :is_member, :boolean
    field :is_admin, :boolean
  end

  object :add_attendance do
    field :id, :integer
    field :training_id, :integer
    field :member_id, :integer
  end

  # import_types OasWeb.Schema.SchemaTypes

  # QUERIES
  object :attendance_queries do
    field :attendance, list_of(:memberAttendance) do 
      arg :training_id, non_null(:integer)
      resolve fn _, %{training_id: training_id}, _ ->
        results = from(m in Oas.Members.Member,
        inner_join: a in assoc(m, :attendance),
        select: {m, a},
          where: a.training_id == ^training_id
        ) |> Oas.Repo.all
        |> Enum.map(fn {member, attendance} -> 
          Map.put(member, :attendance_id, attendance.id)
        end)
        |> Enum.map(fn record ->
          %{id: id} = record
          tokens = Oas.Attendance.get_token_amount(%{member_id: id})
          Map.put(record, :tokens, tokens)
        end)

        {:ok, results}
      end
    end
  end

  object :attendance_mutations do
    # MUTATIONS
    @desc "Add attendance"
    field :add_attendance, type: :add_attendance do
      arg :member_id, non_null(:integer)
      arg :training_id, non_null(:integer)
      resolve fn _, args, _ ->
        Oas.Attendance.add_attendance(args)
      end
    end

    field :delete_attendance, type: :success do
      arg :attendance_id, non_null(:integer)
      resolve fn _, args, _ ->
        Oas.Attendance.delete_attendance(args)
      end
    end
  end
  
end