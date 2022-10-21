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

  def add_attendance(%{member_id: member_id, training_id: training_id}) do
    training = Oas.Repo.get!(Oas.Trainings.Training, training_id)
    member = Oas.Repo.get!(Oas.Members.Member, member_id)

    attendance = %Oas.Trainings.Attendance{
      member_id: member_id,
      training_id: training_id
    } |> Oas.Repo.insert!

    get_unsued_token_result = get_unused_token(member_id)

    case get_unsued_token_result do
      nil -> nil
      token -> use_token(token, attendance.id)
    end

    {:ok, %{id: attendance.id}}
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
      where: a.member_id == ^member_id and is_nil(to.id),
      select: a.id,
      order_by: [asc: tr.when, asc: tr.id],
      limit: ^quantity
    ) |> Oas.Repo.all


    token = %Oas.Tokens.Token{
      member_id: member_id,
      transaction_id: transaction_id,
      expires_on: Date.add(when1, 365), # add a year
      attendance_id: nil,
      value: value
    }

    debtAttendancesStream = Stream.concat(debtAttendances, Stream.cycle([nil]))

    toInsert = List.duplicate(token, quantity)
      |> Enum.zip_with(debtAttendancesStream, fn
        a, nil -> a
        a, id -> %{a | attendance_id: id, used_on: Date.utc_today()} end
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
end