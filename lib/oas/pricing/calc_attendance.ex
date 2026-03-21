import Ecto.Query, only: [from: 2]

defmodule Oas.Pricing.CalcAttendance do


  def apply(%{pricing_instance: nil} = training, attendance, member) do
    Oas.Credits.Credit.deduct_credit(
      attendance,
      member,
      Decimal.sub(
        0,
        calculate_without_pricing(training)
      ),
      %{
        now: training.when,
        attendance: attendance,
        disable_warning_emails: training.disable_warning_emails
      }
    )
  end
  def apply(training, attendance, member) do
    lua_code = training.pricing_instance.blockly_lua

    {_member, membership_status} = Oas.Attendance.check_membership(member)
    membership_status = if membership_status in [:honorary_member, :member], do: :full_member, else: membership_status

    {[result], _} = Lua.new()
    |> Lua.set!([:user, :membership_status], membership_status)
    |> Lua.eval!(lua_code)

    training_spread = from(t in Oas.Trainings.Training,
      inner_join: a in assoc(t, :attendance),
      inner_join: c in assoc(a, :credit),
      preload: [attendance: {a, [credit: c]}],
      where: a.member_id == ^member.id and t.pricing_instance_id == ^training.pricing_instance_id
    ) |> Oas.Repo.all()

    if (Enum.any?(training_spread, fn %{id: id} -> id == training.id end)) do
      raise "This user is already in this training somehow?"
    end

    amount = Decimal.from_float(result) |> Decimal.round(2, :down)

    [ first_item_amount | item_amounts] = distribute_amount([training | training_spread] |> length(), amount)
    # Insert this attendance,
    Oas.Credits.Credit.deduct_credit(
      attendance,
      member,
      Decimal.sub(
        0,
        first_item_amount
      ),
      %{
        now: training.when,
        attendance: attendance,
        disable_warning_emails: training.disable_warning_emails
      }
    )
    # update other attendances
    Enum.map(Enum.zip(training_spread, item_amounts), fn ({training, item_amount}) ->
      [attendance] = training |> Map.get(:attendance) # Should only be one

      %{sign: -1} = amount = Decimal.sub(
        0,
        item_amount
      )

      attendance.credit
      |> Ecto.Changeset.cast(%{
        amount: amount
      },
        [:amount]
      )
      |> Oas.Repo.update()
    end)

    IO.inspect(result, label: "002")
  end

  defp distribute_amount(length, %Decimal{coef: coef} = amount)
    when is_integer(length) and length > 0 and is_integer(coef) do

    base_coef = div(coef, length)
    remainder = rem(coef, length)

    base_dec = %{amount | coef: base_coef}
    bumped_dec = %{amount | coef: base_coef + 1}

    List.duplicate(bumped_dec, remainder) ++ List.duplicate(base_dec, length - remainder)
  end

  defp calculate_without_pricing(training) do
    training_where = training |> Map.get(:training_where) || %{}
    training_where_time = (training_where || %{}) |> Map.get(:training_where_time) |> List.first() || %{}

    (training  |> Map.get(:credit_amount)) ||
    (training_where_time |> Map.get(:credit_amount)) ||
    (training_where |> Map.get(:credit_amount)) ||
    Oas.Config.Tokens.get_min_token().value
  end
end
