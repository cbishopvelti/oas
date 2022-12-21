import Ecto.Query, only: [from: 2, where: 3]

defmodule OasWeb.Schema.SchemaAttendance do
  use Absinthe.Schema.Notation

  object :attendance do
    field :id, :integer
    field :when, :string
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
    field :member_status, :string do
      resolve fn %{id: id, attendance: attendance}, _, _ ->
        when1 = case attendance do
          [attend] ->
            attend |> Oas.Repo.preload(:training) |> Map.get(:training) |> Map.get(:when)
          _ -> Date.utc_today()
        end

        member = from(m in Oas.Members.Member,
          as: :member,
          preload: [membership_periods: ^from(mp in Oas.Members.MembershipPeriod, where: mp.from <= ^when1 and mp.to >= ^when1)],
          select: m,
          where: m.id == ^id
        ) |> Oas.Repo.one!
        {_, membership_type} = Oas.Attendance.check_membership(member)
        {:ok, membership_type}
      end
    end
    field :warnings, list_of(:string)
  end

  object :add_attendance do
    field :id, :integer
    field :training_id, :integer
    field :member_id, :integer
  end

  object :member_attendance_attendance do
    field :id, :integer
    field :member, :member do
      resolve fn
        %{training: %{when: when1}, member: member}, _, _ ->
          {:ok, Map.put(member, :member_status_when, when1)}
        %{member: member}, _, _ ->
          {:ok, member}
      end
    end
    field :token, :token
    field :training, :training
    field :warnings, list_of(:string)
  end

  # import_types OasWeb.Schema.SchemaTypes

  # QUERIES
  object :attendance_queries do
    field :attendance, list_of(:member_attendance_attendance) do 
      arg :training_id, non_null(:integer)
      resolve fn _, %{training_id: training_id}, _ ->
        training = Oas.Repo.get!(Oas.Trainings.Training, training_id)

        results = from(a in Oas.Trainings.Attendance,
          inner_join: m in assoc(a, :member),
          preload: [member: [membership_periods: ^from(mp in Oas.Members.MembershipPeriod, where: mp.from <= ^training.when and mp.to >= ^training.when)]],
          select: a,
          where: a.training_id == ^training_id,
          order_by: [desc: a.id]
        )
        |> Oas.Repo.all
        |> Enum.map(fn record ->
          %{member: member} = record
          tokens = Oas.Attendance.get_token_amount(%{member_id: member.id})
          record = Map.put(record, :tokens, tokens)
          record = if (tokens < 0) do
            Map.put(record, :warnings, ["No tokens left" | Map.get(record, :warnings, [])])
          else
            record
          end

          case Oas.Attendance.check_membership(member) do
            {%{warnings: warnings}, _} -> Map.put(record, :warnings, warnings)
            _ -> record
          end
        end)

        {:ok, results}
      end
    end
    field :member_attendance, list_of(:member_attendance_attendance) do
      arg :member_id, non_null(:integer)
      resolve fn _, %{member_id: member_id}, _ ->
        results = from(at in Oas.Trainings.Attendance,
          inner_join: m in assoc(at, :member),
          left_join: to in assoc(at, :token),
          inner_join: tr in assoc(at, :training),
          preload: [member: m, token: {to, [:transaction]}, training: {tr, [:training_where]}],
          where: m.id == ^member_id,
          order_by: [desc: tr.when, desc: tr.id]
        ) |> Oas.Repo.all

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
      resolve fn _, args, %{context: %{current_member: %{id: inserted_by_member_id}}} ->
        Oas.Attendance.add_attendance(args, %{inserted_by_member_id: inserted_by_member_id})
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