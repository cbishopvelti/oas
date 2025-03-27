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

  defp get_used_on(nil) do
    nil
  end
  defp get_used_on(training_when) do
    case Date.compare(Date.utc_today(), training_when) do
      :lt -> training_when
      _ -> Date.utc_today
    end
  end

  def use_token(token, attendance_id, training_when) do
    Ecto.Changeset.change(token,
      used_on: get_used_on(training_when),
      attendance_id: attendance_id)
      |> Oas.Repo.update!
    :ok
  end

  defp get_membership_periods(when1) do
    from(mp in Oas.Members.MembershipPeriod,
      where: (mp.from <= ^when1 and ^when1 <= mp.to),
      order_by: [asc: mp.from]
    ) |> Oas.Repo.all()
  end

  defp add_attendance_membership(training, %{membership_periods: []} = member, %{now: now}) do
    case check_membership(member) do
      {_, membership} when membership == :x_member or membership == :not_member or membership == :honorary_member ->
        case get_membership_periods(training.when) do
          nil -> nil # No membership period to add to
          [] -> nil
          membership_periods ->
            membership_periods |> Enum.map(fn membership_period ->
              Oas.Members.Membership.add_membership(membership_period, member, %{now: now})
            end)
            nil
        end
      _membership -> # Temporary_member
        nil
    end
  end
  defp add_attendance_membership(_, _, _) do # already a member, do nothing
    nil
  end

  def add_attendance(%{member_id: member_id, training_id: training_id}, %{inserted_by_member_id: inserted_by_member_id}) do
    training = Oas.Repo.get!(Oas.Trainings.Training, training_id)
    |> Oas.Repo.preload(:training_where)

    now = Date.utc_today()

    member = Oas.Repo.get!(Oas.Members.Member, member_id)
    |> Oas.Repo.preload([
      membership_periods: from(
        mp in Oas.Members.MembershipPeriod,
        where: mp.from <= ^training.when and mp.to >= ^training.when
      )
    ])

    # FIX DEBT
    attendance = %Oas.Trainings.Attendance{
      member_id: member_id,
      training_id: training_id,
      inserted_by_member_id: inserted_by_member_id,
    }
    |> Oas.Repo.insert!

    get_unsued_token_result = get_unused_token(member_id)

    config = from(
      c in Oas.Config.Config,
      limit: 1
    ) |> Oas.Repo.one!()

    if config.credits do # Membership
      add_attendance_membership(
        training,
        member,
        %{now: now}
      )
    end

    case get_unsued_token_result do
      nil -> # User has no tokens, use credits instead
        if (config.credits) do
          Oas.Credits.Credit.deduct_credit(
            attendance,
            member,
            Decimal.sub(
              0,
              training.training_where.credit_amount || Oas.Config.Tokens.get_min_token().value
            ),
            %{
              now: now
            }
          )
        else
          nil
        end
      token -> use_token(token, attendance.id, training.when)
    end

    Task.async(fn ->
      Oas.TokenMailer.maybe_send_warnings_email(member)
    end)

    {:ok, %{id: attendance.id}}
  end

  def delete_attendance(%{attendance_id: attendance_id}) do
    attendance = Oas.Repo.get!(Oas.Trainings.Attendance, attendance_id)
      |> Oas.Repo.preload(:token)
      |> Oas.Repo.preload(:member)
      |> Oas.Repo.preload(:training)

    if (attendance.token != nil) do
      debtAttendance = from(a in Oas.Trainings.Attendance,
        left_join: to in assoc(a, :token), on: to.member_id == ^attendance.member.id,
        inner_join: tr in assoc(a, :training),
        left_join: c in assoc(a, :credit),
        preload: [training: tr],
        where: a.member_id == ^attendance.member.id and is_nil(to.id) and is_nil(c.id),
        select: a,
        order_by: [asc: tr.when, asc: tr.id],
        limit: 1
      ) |> Oas.Repo.one

      case debtAttendance do
        nil ->
          attendance.token |>
            Ecto.Changeset.cast(%{used_on: nil, attendance_id: nil}, [:used_on, :attendance_id])
            |> Oas.Repo.update!
        %{id: id, training: %{when: _when1}} ->
          attendance.token |>
            Ecto.Changeset.cast(%{used_on: get_used_on(attendance.training.when), attendance_id: id}, [:used_on, :attendance_id])
            |> Oas.Repo.update!
      end
    end

    # Maybe delete membership
    Oas.Members.Membership.maybe_delete_membership(
      attendance.training,
      attendance.member
    )
    # EO maybe delete membership

    Oas.Repo.delete!(attendance)

    {:ok, %{success: true}}
  end

  def get_token_amount(%{member_id: member_id}) do

    debtAttendances = from(a in Oas.Trainings.Attendance,
      left_join: t in assoc(a, :token), on: t.member_id == ^member_id,
      left_join: c in assoc(a, :credit),
      where: a.member_id == ^member_id and is_nil(t.id) and is_nil(c.id),
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
      # {x, y} -> -x
    end
  end

  def add_tokens_changeset(changeset, %{
    member_id: member_id,
    quantity: quantity,
    when1: when1,
    value: value
  }) do
    # FIX DEBT
    config = from(cc in Oas.Config.Config, select: cc) |> Oas.Repo.one
    debtAttendances = from(a in Oas.Trainings.Attendance,
      left_join: to in assoc(a, :token), on: to.member_id == ^member_id,
      inner_join: tr in assoc(a, :training),
      left_join: c in assoc(a, :credit),
      preload: [training: tr],
      where: a.member_id == ^member_id and is_nil(to.id) and is_nil(c.id),
      select: a,
      order_by: [asc: tr.when, asc: tr.id],
      limit: ^quantity
    ) |> Oas.Repo.all

    token = %Oas.Tokens.Token{
      member_id: member_id,
      expires_on: Date.add(when1, config.token_expiry_days), # add a year
      attendance_id: nil,
      value: value
    }

    debtAttendancesStream = Stream.concat(debtAttendances, Stream.cycle([nil]))

    tokens = List.duplicate(token, quantity)
    |> Enum.zip_with(debtAttendancesStream, fn
      a, nil -> a
      a, %{id: id, training: %{when: when1}} ->
        %{a | attendance_id: id, used_on: get_used_on(when1)}
      end
    )

    changeset |> Ecto.Changeset.put_assoc(:tokens, tokens)
  end

  def add_tokens(%{
    member_id: member_id,
    transaction_id: transaction_id,
    quantity: quantity,
    when1: when1,
    value: value
  }, do_insert \\ true) do
    # FIX DEBT
    config = from(cc in Oas.Config.Config, select: cc) |> Oas.Repo.one
    debtAttendances = from(a in Oas.Trainings.Attendance,
      left_join: to in assoc(a, :token), on: to.member_id == ^member_id,
      inner_join: tr in assoc(a, :training),
      left_join: c in assoc(a, :credit),
      preload: [training: tr],
      where: a.member_id == ^member_id and is_nil(to.id) and is_nil(c.id),
      select: a,
      order_by: [asc: tr.when, asc: tr.id],
      limit: ^quantity
    ) |> Oas.Repo.all

    token = %Oas.Tokens.Token{
      member_id: member_id,
      transaction_id: transaction_id,
      expires_on: Date.add(when1, config.token_expiry_days), # add a year
      attendance_id: nil,
      value: value
    }

    debtAttendancesStream = Stream.concat(debtAttendances, Stream.cycle([nil]))

    tokens = List.duplicate(token, quantity)
    |> Enum.zip_with(debtAttendancesStream, fn
      a, nil -> a
      a, %{id: id, training: %{when: when1}} ->
        %{a | attendance_id: id, used_on: get_used_on(when1)}
      end
    )

    if (do_insert) do
      tokens |> Enum.map(&Oas.Repo.insert/1)
      :ok
    else
      tokens
    end
  end


  def transfer_token(%{member_id: member_id, token: token}) do

    # FIX DEBT
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
      |> Ecto.Changeset.cast(%{member_id: member_id, attendance_id: attendanceId, used_on: get_used_on(when1)}, [:member_id, :attendance_id, :used_on])
      |> Oas.Repo.update
    token
  end

  def check_membership(member = %{id: id, membership_periods: []}) do
    result = from(a in Oas.Trainings.Attendance,
      join: m in assoc(a, :member),
      where: m.id == ^id,
      select: count(m.id)
    ) |> Oas.Repo.one

    config = from(c in Oas.Config.Config, select: c)
      |> Oas.Repo.one

    cond do
      (member.honorary_member) ->
        {member, :honorary_member}
      (member
        |> Oas.Repo.preload(:memberships, force: true)
        |> Map.get(:memberships)
        |> Enum.count) > 0 ->
        {
          Map.put(member, :warnings, [member.name <> " is an x-member" | Map.get(member, :warnings, []) ]),
          :x_member
        }
      result > config.temporary_trainings ->
        {
          Map.put(member, :warnings, [member.name <> " has attended " <> to_string(result)
            <> " session"
            <> case result do
              1 -> ""
              _ -> "s"
            end
            <> " but is not a member" | Map.get(member, :warnings, [])]),
          :not_member
        }
      true ->
        {member, :temporary_member}
    end
  end
  def check_membership(member) do
    {member, :member}
  end
end
