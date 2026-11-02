import Ecto.Query, only: [from: 2]

defmodule Oas.Pricing.CalcAttendance do

  @doc """
    Calculates an array of prices for all items in a pricing_instance to be applied.

    ## Options

      * `:distribution_mode` - Determines how the price is distributed across items.
        Accepted values are `:redistribute` (default) or `:remaining`.
        `:remaining` puts the bundle price minus what the member has already
        paid on this training, for showing the price before booking.
      * `:delete` - If we are deleting the training
    """
  def calculate_price(training, member, opts \\ [])
  def calculate_price(%{pricing_instance: nil} = training, _member, _opts) do
    [ {training, calculate_without_pricing(training)}]
  end
  def calculate_price(training, member, opts) do
    lua_code = training.pricing_instance.blockly_lua

    {_member, membership_status} = Oas.Attendance.check_membership(member)
    membership_status = if membership_status in [:honorary_member, :member], do: :full_member, else: membership_status

    {trainings, attending} = from(t in Oas.Trainings.Training,
      left_join: a in assoc(t, :attendance), on: a.member_id == ^member.id,
      preload: [training_where: [:training_where_time], attendance: a],
      where: t.pricing_instance_id == ^training.pricing_instance_id
    ) |> Oas.Repo.all()
    |> Enum.with_index()
    |> Enum.map(fn ({train, index}) ->
      IO.inspect(train, label: "100 -----")
      IO.inspect(Keyword.get(opts, :delete, false), label: "100.1")
      IO.inspect(opts, label: "100.2")
      {
        train |> calculate_without_pricing() |> Decimal.to_float(),
        # Add exsting attendances, or this training
        if(train.attendance != [] or (!Keyword.get(opts, :delete, false) && train.id == training.id), do: (index + 1) / 1, else: nil)
      }
    end)
    |> Enum.unzip()
    attending = Enum.reject(attending, &is_nil/1)
    now = Date.utc_today() |> Date.to_string()

    {[result], _} = Lua.new()
    |> Lua.set!([:user, :membership_status], membership_status)
    |> Lua.set!([:user, :attending], attending)
    |> Lua.set!([:trainings], trainings)
    |> Lua.set!([:now], now)
    |> Lua.eval!(lua_code)

    training_spread = from(t in Oas.Trainings.Training,
      inner_join: a in assoc(t, :attendance),
      inner_join: c in assoc(a, :credit),
      preload: [attendance: {a, [credit: c]}],
      where: a.member_id == ^member.id and t.pricing_instance_id == ^training.pricing_instance_id
    ) |> Oas.Repo.all()



    # Assume we're trying to recalculate the the amount for this training, even though we're already attending this training.
    training_spread = Enum.reject(training_spread, fn %{id: id} -> id == training.id end)
    # if (Enum.any?(training_spread, fn %{id: id} -> id == training.id end)) do
    #   raise "This user is already in this training somehow?"
    # end

    amount = lua_result_to_decimal(result) |> Decimal.round(2, :down)
    dbg(amount)

    case Keyword.get(opts, :distribution_mode, :redistribute) do
      :redistribute ->
        case Keyword.get(opts, :delete, false) do
          true -> # Deleteing
            item_amounts = distribute_amount(training_spread |> length(), amount)
            Enum.zip(training_spread, item_amounts)
          false -> # Inserting
            [ first_item_amount | item_amounts] = distribute_amount([training | training_spread] |> length(), amount)
            [ {training, first_item_amount} | Enum.zip(training_spread, item_amounts)]
        end
      :remaining ->
        # Shows what booking this training would cost on top of what the member
        # has already paid. training_spread only holds trainings this member
        # attends with a credit (inner join), so they are all already paid for.
        {out, already_amount} = training_spread |> Enum.map_reduce(Decimal.new("0"), fn training, acc ->
          amount = training |> Map.get(:attendance) |> List.first() |> Map.get(:credit) |> Map.get(:amount) |> Decimal.abs()
          {
            {
              training,
              amount
            },
            Decimal.add(acc, amount)
          }
        end)

        # The whole remaining amount falls on this training
        [{training, Decimal.sub(amount, already_amount)} | out]
    end
  end

  def apply(%{pricing_instance: nil} = training, attendance, member) do
    Oas.Credits.Credit.deduct_credit(
      attendance,
      member,
      Decimal.sub(
        0,
        calculate_price(training, member) |> List.first() |> elem(1)
      ),
      %{
        now: training.when,
        attendance: attendance,
        disable_warning_emails: training.disable_warning_emails
      }
    )
  end
  def apply(training, attendance, member) do

    [ first_item_amount | item_amounts] = calculate_price(training, member)

    # Insert this attendance,
    Oas.Credits.Credit.deduct_credit(
      attendance,
      member,
      Decimal.sub(
        0,
        first_item_amount |> elem(1)
      ),
      %{
        now: training.when,
        attendance: attendance,
        disable_warning_emails: training.disable_warning_emails
      }
    )

    # update other attendances
    Enum.map(item_amounts, fn ({training, item_amount}) ->
      [attendance] = training |> Map.get(:attendance) # Should only be one

      amount = to_debit_amount(item_amount)

      attendance.credit
      |> Ecto.Changeset.cast(%{
        amount: amount
      },
        [:amount]
      )
      |> Oas.Repo.update()

      Absinthe.Subscription.publish(OasWeb.Endpoint, %{success: true}, user_attendance_attendance: member.id)
      Absinthe.Subscription.publish(OasWeb.Endpoint, %{id: training.id}, attendance_attendance: training.id)
    end)
  end

  def apply_delete(%{pricing_instance: nil}, _attendance, _member) do
    # Nothing, as there are no related trainings.
  end
  def apply_delete(training, _attendance, member) do
    item_amounts = calculate_price(training, member, delete: true)

    Enum.map(item_amounts, fn ({training, item_amount}) ->
      [attendance] = training |> Map.get(:attendance) # Should only be one
      amount = to_debit_amount(item_amount)

      attendance.credit
      |> Ecto.Changeset.cast(%{
        amount: amount
      },
        [:amount]
      )
      |> Oas.Repo.update()

      Absinthe.Subscription.publish(OasWeb.Endpoint, %{success: true}, user_attendance_attendance: member.id)
      Absinthe.Subscription.publish(OasWeb.Endpoint, %{id: training.id}, attendance_attendance: training.id)
    end)
  end

  @doc false
  # The Lua script receives prices as floats (via Decimal.to_float/1), so its
  # result is usually a float, but may be an integer or a numeric string.
  # Decimal.new/1 does not accept floats, so convert explicitly.
  def lua_result_to_decimal(%Decimal{} = result), do: result
  def lua_result_to_decimal(result) when is_integer(result), do: Decimal.new(result)
  def lua_result_to_decimal(result) when is_float(result), do: Decimal.from_float(result)
  def lua_result_to_decimal(result) when is_binary(result), do: Decimal.new(String.trim(result))
  def lua_result_to_decimal(result) do
    raise ArgumentError, "Pricing Lua script must return a number, got: #{inspect(result)}"
  end

  @doc false
  # Converts a non-negative price into the credit amount to store (negative, or
  # zero for a free training). Decimal zero has sign 1, so a zero price can't be
  # matched with %{sign: -1}.
  def to_debit_amount(item_amount) do
    if Decimal.negative?(item_amount) do
      raise ArgumentError, "Expected a non-negative price, got: #{Decimal.to_string(item_amount)}"
    end

    Decimal.sub(0, item_amount)
  end

  defp distribute_amount(length, %Decimal{coef: 0} = zero) do
    List.duplicate(zero, length)
  end
  defp distribute_amount(0, %Decimal{coef: coef}) do
    []
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
