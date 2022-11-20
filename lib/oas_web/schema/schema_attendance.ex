import Ecto.Query, only: [from: 2, where: 3]

defmodule OasWeb.Schema.SchemaAttendance do
  use Absinthe.Schema.Notation

  object :attendance do
    field :id, :integer
  end

  object :member_attendance do
    field :id, :integer
    field :attendance_id, :integer
    field :attendance, list_of(:attendance)
    field :name, :string
    field :email, :string
    field :tokens, :integer
    field :is_member, :boolean
    field :is_admin, :boolean
    field :warnings, list_of(:string)
  end

  object :add_attendance do
    field :id, :integer
    field :training_id, :integer
    field :member_id, :integer
  end

  # import_types OasWeb.Schema.SchemaTypes

  # QUERIES
  object :attendance_queries do
    field :attendance, list_of(:member_attendance) do 
      arg :training_id, non_null(:integer)
      resolve fn _, %{training_id: training_id}, _ ->
        training = Oas.Repo.get!(Oas.Trainings.Training, training_id)

        results = from(m in Oas.Members.Member,
          as: :member,
          inner_join: a in assoc(m, :attendance),
          preload: [attendance: a],
          preload: [membership_periods: ^from(mp in Oas.Members.MembershipPeriod, where: mp.from <= ^training.when and mp.to >= ^training.when)],
          select: m,
          where: a.training_id == ^training_id
        )
        |> Oas.Repo.all
        |> Enum.map(fn record ->
          %{id: id} = record
          tokens = Oas.Attendance.get_token_amount(%{member_id: id})
          record = Map.put(record, :tokens, tokens)
          record = if (tokens < 0) do
            Map.put(record, :warnings, ["No tokens left" | Map.get(record, :warnings, [])])
          else
            record
          end
          {record, _} = Oas.Attendance.check_membership(record)
          record
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