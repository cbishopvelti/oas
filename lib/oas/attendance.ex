import Ecto.Query, only: [from: 2]

defmodule Oas.Attendance do

  def get_unused_token(member_id) do
    query = from(
      t in Oas.Tokens.Token,
      where: t.member_id == ^member_id and t.expires_on >= from_now(0, "day") and is_nil(t.used_on),
      limit: 1,
      order_by: [asc: t.expires_on, asc: t.id]
    )
    result = Oas.Repo.one(query)

    result
  end

  def use_token(token, attendance_id) do
    Ecto.Changeset.change(token,
      used_on: Date.utc_today,
      attendance_id: attendance_id)
      |> Oas.Repo.update!
    :ok
  end

  def maybe_send_warnings_email(member) do
    lastTransaction = from(t in Oas.Transactions.Transaction, 
      order_by: [desc: t.when, desc: t.id],
      limit: 1
    ) |> Oas.Repo.one

    attendance = from(a in Oas.Trainings.Attendance,
      inner_join: m in assoc(a, :member),
      inner_join: tr in assoc(a, :training),
      preload: [:token, training: tr],
      where: m.id == ^member.id,
      order_by: [desc: tr.when, desc: a.id],
      limit: 2
    ) |> Oas.Repo.all

    case attendance do
      [firstAttendance, %{token: nil, training: %{when: when1}}] when when1 > lastTransaction.when  ->
        nil
      _ ->
        maybe_send_warnings_email_2(member)
    end

  end

  def maybe_send_warnings_email_2(member) do
    
    warnings = []
    tokens = Oas.Attendance.get_token_amount(%{member_id: member.id})
    warnings = if (tokens <= 0) do
      warnings = ["You have run out of tokens (#{tokens}), please buy more" | warnings]
    else
      warnings
    end

    warnings = case check_membership(member) do
      {_, :not_member} -> ["You are not a valid member, please pay for membership" | warnings]
      {_, :x_member} -> ["You are not a valid member, please pay for membership" | warnings]
      _ -> warnings
    end

    case (warnings) do
      [] -> nil
      warnings -> 
        Oas.Tokens.TokenNotifier.deliver(member.email, "OAS notification", """
          Hi #{member.name}

          #{Enum.join(warnings, "\n")}

          Thanks

          OAS
        """)
    end

  end

  def add_attendance(%{member_id: member_id, training_id: training_id}) do
    training = Oas.Repo.get!(Oas.Trainings.Training, training_id)
    member = Oas.Repo.get!(Oas.Members.Member, member_id)
    |> Oas.Repo.preload([membership_periods: from(mp in Oas.Members.MembershipPeriod, where: mp.from <= ^training.when and mp.to >= ^training.when)])

    attendance = %Oas.Trainings.Attendance{
      member_id: member_id,
      training_id: training_id
    } |> Oas.Repo.insert!

    get_unsued_token_result = get_unused_token(member_id)

    case get_unsued_token_result do
      nil -> nil
      token -> use_token(token, attendance.id)
    end

    Task.async(fn ->
      maybe_send_warnings_email(member)
    end)

    {:ok, %{id: attendance.id}}
  end

  def delete_attendance(%{attendance_id: attendance_id}) do
    attendance = Oas.Repo.get!(Oas.Trainings.Attendance, attendance_id)
      |> Oas.Repo.preload(:token)
      |> Oas.Repo.preload(:member)

    if (attendance.token != nil) do
      debtAttendance = from(a in Oas.Trainings.Attendance,
        left_join: to in assoc(a, :token), on: to.member_id == ^attendance.member.id,
        inner_join: tr in assoc(a, :training),
        preload: [training: tr],
        where: a.member_id == ^attendance.member.id and is_nil(to.id),
        select: a,
        order_by: [asc: tr.when, asc: tr.id],
        limit: 1
      ) |> Oas.Repo.one

      attendance_id = case debtAttendance do
        nil -> 
          attendance.token |>
            Ecto.Changeset.cast(%{used_on: nil, attendance_id: nil}, [:used_on, :attendance_id])
            |> Oas.Repo.update!
        %{id: id, training: %{when: when1}} -> 
          attendance.token |>
            Ecto.Changeset.cast(%{used_on: when1, attendance_id: id}, [:used_on, :attendance_id])
            |> Oas.Repo.update!
      end
    end
    
    Oas.Repo.delete!(attendance)

    {:ok, %{success: true}}
  end

  def get_token_amount(%{member_id: member_id}) do
    debtAttendances = from(a in Oas.Trainings.Attendance,
      left_join: t in assoc(a, :token), on: t.member_id == ^member_id,
      where: a.member_id == ^member_id and is_nil(t.id),
      select: count(a.id)
    ) |> Oas.Repo.one

    creditTokens = from(t in Oas.Tokens.Token, 
      where: t.member_id == ^member_id and t.expires_on >= from_now(0, "day") and is_nil(t.used_on),
      select: count(t.id)
    ) |> Oas.Repo.one

    if (Kernel.and(debtAttendances > 0, creditTokens > 0)) do
      raise "There are both debtAttendances and creditTokens. This should not happen"
    end

    case {debtAttendances, creditTokens} do
      {x, 0} -> -x
      {0, x} -> x
    end
  end

  def add_tokens(%{
    member_id: member_id,
    transaction_id: transaction_id,
    quantity: quantity,
    when1: when1,
    value: value
  }) do
    debtAttendances = from(a in Oas.Trainings.Attendance,
      left_join: to in assoc(a, :token), on: to.member_id == ^member_id,
      inner_join: tr in assoc(a, :training),
      preload: [training: tr],
      where: a.member_id == ^member_id and is_nil(to.id),
      select: a,
      order_by: [asc: tr.when, asc: tr.id],
      limit: ^quantity
    ) |> Oas.Repo.all

    config = from(cc in Oas.Config.Config, select: cc) |> Oas.Repo.one

    token = %Oas.Tokens.Token{
      member_id: member_id,
      transaction_id: transaction_id,
      expires_on: Date.add(when1, config.token_expiry_days), # add a year
      attendance_id: nil,
      value: value
    }

    debtAttendancesStream = Stream.concat(debtAttendances, Stream.cycle([nil]))

    toInsert = List.duplicate(token, quantity)
      |> Enum.zip_with(debtAttendancesStream, fn
        a, nil -> a
        a, %{id: id, training: %{when: when1}} -> %{a | attendance_id: id, used_on: when1} end
      )
      |> Enum.map(&Oas.Repo.insert/1)

    :ok
  end


  def transfer_token(%{member_id: member_id, token: token}) do

    {attendanceId, when1} = from(a in Oas.Trainings.Attendance,
      left_join: to in assoc(a, :token), on: to.member_id == ^member_id,
      inner_join: tr in assoc(a, :training),
      where: a.member_id == ^member_id and is_nil(to.id),
      select: {a.id, tr.when},
      order_by: [asc: tr.when, asc: tr.id],
      limit: 1
    ) |> Oas.Repo.one |> case do
      nil -> {nil, nil}
      x -> x
    end

    {:ok, token} = token
      |> Ecto.Changeset.cast(%{member_id: member_id, attendance_id: attendanceId, used_on: when1}, [:member_id, :attendance_id, :used_on])
      |> Oas.Repo.update
    token
  end

  def check_membership(member = %{id: id, membership_periods: []}) do
    result = from(a in Oas.Trainings.Attendance,
      join: m in assoc(a, :member),
      where: m.id == ^id,
      select: count(m.id)
    ) |> Oas.Repo.one

    if (
      result > 3
    ) do
      {
        Map.put(member, :warnings, [member.name <> " has attended " <> to_string(result) <> " sessions but is not a member" | Map.get(member, :warnings, [])]),
        :not_member
      }
    else
      if (
        (member
        |> Oas.Repo.preload(:memberships)
        |> Map.get(:memberships)
        |> Enum.count) > 0
      ) do
        {
          Map.put(member, :warnings, [member.name <> " is an x-member" | Map.get(member, :warnings, []) ]),
          :x_member
        }
      else
        {member, :temporary_member}
      end
    end
  end
  def check_membership(member) do
    {member, :member}
  end
end