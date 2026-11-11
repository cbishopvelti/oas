import Ecto.Query, only: [from: 2]

defmodule Oas.Pricing.CalcAttendance do
  require Logger

  # Limits for running a pricing rule. A rule that loops forever or builds huge
  # tables must not hang or take down a member's booking.
  @default_lua_timeout_ms 2_000
  # In words (8 bytes each on 64-bit), so about 64MB.
  @default_lua_max_heap_words 8_000_000

  @price_error "This session's price couldn't be calculated. Please contact an admin."

  @doc """
    Calculates an array of prices for all items in a pricing_instance to be applied.

    ## Options

      * `:distribution_mode` - Determines how the price is distributed across items.
        Accepted values are `:redistribute` (default) or `:remaining`.
        `:remaining` puts the bundle price minus what the member has already
        paid on this training, for showing the price before booking.
      * `:delete` - If we are deleting the training

    Returns a list of `{training, amount}`, or `{:error, message}` when the
    pricing instance's Lua rule fails, times out or doesn't return a valid price.
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
      where: t.pricing_instance_id == ^training.pricing_instance_id,
      order_by: [asc: t.when, asc: t.start_time, asc: t.id]
    ) |> Oas.Repo.all()
    |> Enum.with_index()
    |> Enum.map(fn ({train, index}) ->
      {
        train |> calculate_without_pricing() |> Decimal.to_float(),
        # Add exsting attendances, or this training
        if(train.attendance != [] or (!Keyword.get(opts, :delete, false) && train.id == training.id), do: (index + 1) / 1, else: nil)
      }
    end)
    |> Enum.unzip()
    attending = Enum.reject(attending, &is_nil/1)
    now = training.when |> Date.to_string()

    inputs = %{
      membership_status: membership_status,
      attending: attending,
      trainings: trainings,
      now: now
    }

    case run_lua(lua_code, inputs) do
      {:ok, amount} ->
        spread_price(training, member, amount, opts)

      {:error, reason} ->
        Logger.error(
          "Pricing rule failed for pricing_instance #{training.pricing_instance_id}, " <>
            "training #{training.id}, member #{member.id}: #{reason}"
        )

        {:error, @price_error}
    end
  end

  defp spread_price(training, member, amount, opts) do
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

    amount = Decimal.round(amount, 2, :down)

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

  @doc """
    Deducts credit for a new attendance and re-spreads the price over the member's
    other attendances in the same pricing instance.

    Returns `{:ok, attendance, respread_training_ids}` or `{:error, reason}`.
    Callers run this inside a transaction and must roll back on error, otherwise
    the attendance is kept without its credit. Once the transaction has
    committed, they pass the ids to `publish_respread/2` and queue the member's
    warning email.
    """
  def apply(%{pricing_instance: nil} = training, attendance, member) do
    with {:ok, attendance} <- Oas.Credits.Credit.deduct_credit(
           attendance,
           member,
           Decimal.sub(
             0,
             calculate_price(training, member) |> List.first() |> elem(1)
           ),
           %{now: training.when}
         ) do
      {:ok, attendance, []}
    end
  end
  def apply(training, attendance, member) do

    # Insert this attendance, then update other attendances
    with [ first_item_amount | item_amounts] <- calculate_price(training, member),
         {:ok, attendance} <- Oas.Credits.Credit.deduct_credit(
           attendance,
           member,
           Decimal.sub(
             0,
             first_item_amount |> elem(1)
           ),
           %{now: training.when}
         ),
         {:ok, training_ids} <- update_credit_amounts(item_amounts) do
      {:ok, attendance, training_ids}
    end
  end

  @doc """
    Re-spreads the price over the member's remaining attendances after one is deleted.

    Returns `{:ok, respread_training_ids}` or `{:error, reason}`; callers must
    roll back on error, and pass the ids to `publish_respread/2` once committed.
    """
  def apply_delete(%{pricing_instance: nil}, _attendance, _member) do
    # Nothing, as there are no related trainings.
    {:ok, []}
  end
  def apply_delete(training, _attendance, member) do
    case calculate_price(training, member, delete: true) do
      {:error, _} = error -> error
      item_amounts -> update_credit_amounts(item_amounts)
    end
  end

  @doc """
    Tells subscribers that the member's credits on these trainings changed. Only
    call it after the transaction that changed them has committed.
    """
  def publish_respread(member, training_ids) do
    Enum.each(training_ids, fn training_id ->
      Absinthe.Subscription.publish(OasWeb.Endpoint, %{success: true}, user_attendance_attendance: member.id)
      Absinthe.Subscription.publish(OasWeb.Endpoint, %{id: training_id}, attendance_attendance: training_id)
    end)
  end

  # Updates the credit of each attendance to its new share of the price. Stops at
  # the first failed write and returns `{:error, changeset}`, otherwise
  # `{:ok, training_ids}` for the trainings whose credit was updated.
  defp update_credit_amounts(item_amounts) do
    item_amounts
    |> Enum.reduce_while({:ok, []}, fn ({training, item_amount}, {:ok, training_ids}) ->
      [attendance] = training |> Map.get(:attendance) # Should only be one
      amount = to_debit_amount(item_amount)

      attendance.credit
      |> Ecto.Changeset.cast(%{
        amount: amount
      },
        [:amount]
      )
      |> Oas.Repo.update()
      |> case do
        {:ok, _credit} -> {:cont, {:ok, [training.id | training_ids]}}
        {:error, changeset} -> {:halt, {:error, changeset}}
      end
    end)
    |> case do
      {:ok, training_ids} -> {:ok, Enum.reverse(training_ids)}
      error -> error
    end
  end

  @doc """
    Runs a pricing rule's Lua code with the given inputs, in a separate process
    with a time limit and a memory limit.

    Returns `{:ok, price}` with a non-negative `Decimal`, or `{:error, reason}`
    when the rule doesn't compile, raises, times out, uses too much memory, or
    doesn't return a non-negative number.

    ## Options

      * `:timeout` - milliseconds to wait (default from
        `config :oas, :pricing_lua, timeout_ms:`, else #{@default_lua_timeout_ms})
      * `:max_heap_words` - process heap limit in words (default from
        `config :oas, :pricing_lua, max_heap_words:`, else #{@default_lua_max_heap_words})
    """
  def run_lua(lua_code, inputs, opts \\ [])
  def run_lua(lua_code, _inputs, _opts) when lua_code in [nil, ""] do
    {:error, "the pricing rule has no Lua code"}
  end
  def run_lua(lua_code, inputs, opts) do
    config = Application.get_env(:oas, :pricing_lua, [])
    timeout = Keyword.get(opts, :timeout, Keyword.get(config, :timeout_ms, @default_lua_timeout_ms))
    max_heap_words = Keyword.get(opts, :max_heap_words, Keyword.get(config, :max_heap_words, @default_lua_max_heap_words))

    task = Task.Supervisor.async_nolink(Oas.TaskSupervisor, fn ->
      Process.flag(:max_heap_size, %{size: max_heap_words, kill: true, error_logger: false})
      eval_lua(lua_code, inputs)
    end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> result
      {:exit, :killed} -> {:error, "the pricing rule used too much memory"}
      {:exit, reason} -> {:error, "the pricing rule crashed: #{inspect(reason)}"}
      nil -> {:error, "the pricing rule took longer than #{timeout}ms"}
    end
  end

  defp eval_lua(lua_code, inputs) do
    {results, _} = Lua.new()
    |> Lua.set!([:user, :membership_status], inputs.membership_status)
    |> Lua.set!([:user, :attending], inputs.attending)
    |> Lua.set!([:trainings], inputs.trainings)
    |> Lua.set!([:now], inputs.now)
    |> Lua.eval!(lua_code)

    case results do
      [] ->
        {:error, "the pricing rule didn't return a price"}

      [result | _] ->
        amount = lua_result_to_decimal(result)

        if Decimal.negative?(amount) do
          {:error, "the pricing rule returned a negative price: #{Decimal.to_string(amount)}"}
        else
          {:ok, amount}
        end
    end
  rescue
    e in Lua.CompilerException ->
      {:error, "the pricing rule doesn't compile: #{Exception.message(e)}"}

    e ->
      {:error, "the pricing rule failed: #{Exception.message(e)}"}
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
    Oas.Settings.get_min_token!().value
  end
end
