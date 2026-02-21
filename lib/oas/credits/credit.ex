import Ecto.Query, only: [from: 2]

defmodule Oas.Credits.Credit do
  use Ecto.Schema
  import Ecto.Changeset

  schema "credits" do
    field :what, :string
    field :amount, :decimal
    belongs_to :member, Oas.Members.Member, foreign_key: :who_member_id
    belongs_to :transaction, Oas.Transactions.Transaction, foreign_key: :transaction_id
    belongs_to :attendance, Oas.Trainings.Attendance, foreign_key: :attendance_id
    belongs_to :membership, Oas.Members.Membership, foreign_key: :membership_id
    belongs_to :credit, Oas.Credits.Credit, foreign_key: :credit_id
    belongs_to :thing, Oas.Things.Thing, foreign_key: :thing_id
    field :when, :date
    field :expires_on, :date

    many_to_many :uses, Oas.Credits.Credit,
      join_through: Oas.Credits.CreditsCredits,
      join_keys: [used_for_id: :id, uses_id: :id],
      unique: true

    has_many :uses_credits_credits, Oas.Credits.CreditsCredits, foreign_key: :used_for_id
    has_many :used_for_credits_credits, Oas.Credits.CreditsCredits, foreign_key: :uses_id

    has_one :debit, Oas.Credits.Credit, foreign_key: :credit_id

    timestamps()
  end

  # defp validate_transaction(changeset) do
  #   cond do
  #     Decimal.gt?(get_field(changeset, :amount), 0) && !get_field(changeset, :transaction_id) ->
  #       add_error(changeset, :transaction_id, "There must be a transaction")
  #     true -> changeset
  #   end
  # end

  def changeset(changeset, params \\ %{}) do
    changeset
    |> cast(params, [
      :what, :who_member_id, :amount,
      :when, :expires_on
    ], empty_values: [[], nil])
  end

  # Called from Transaction
  def doCredit(changeset, nil) do
    case get_assoc(changeset, :credit) do
      nil -> changeset
      _assoc ->
        Ecto.Changeset.put_assoc(changeset, :credit, nil)
    end
  end
  def doCredit(changeset, args) do

    config = from(cc in Oas.Config.Config, select: cc) |> Oas.Repo.one

    out = case get_assoc(changeset, :credit) do
      nil -> %Oas.Credits.Credit{}
      assoc ->
        assoc
    end

    out = case args do
      %{amount: amount} ->

        # if (amount < 0.0) do
        #   raise "Oas.Credits.Credit.doCredit can't be negative"
        # end
        out
        |> changeset(%{
          amount: amount,
          # who_member_id: get_assoc(changeset, :credit) |> List.first() |> get_field()
          who_member_id: get_field(changeset, :who_member_id),
          what: get_field(changeset, :what),
          when: get_field(changeset, :when),
          expires_on: (if amount > 0.0, do: get_field(changeset, :when) |> Date.add(config.token_expiry_days), else: nil)
        })
    end

    Ecto.Changeset.put_assoc(changeset, :credit, out)
  end

  @deprecated "Use Oas.Credits.Credit2.get_credit_amount"
  def get_credit_amount(%{member_id: member_id}) do
    credits = from(c in Oas.Credits.Credit,
      where: c.who_member_id == ^member_id,
      preload: [:transaction, :debit, :credit, :membership, :attendance],
      order_by: [asc: coalesce(c.expires_on, c.when), asc_nulls_first: c.expires_on, asc: c.id]
      # order_by: [asc_nulls_last: c.expires_on, asc: c.when, asc: c.id]
    )
    |> Oas.Repo.all()

    {credits, total} = process_credits(credits)
    {
      credits |> Enum.reverse(),
      total,
    }
  end
  def get_credit_amount_to(%{member_id: member_id}, to) do
    credits = from(c in Oas.Credits.Credit,
      where: c.who_member_id == ^member_id and c.when <= ^to,
      preload: [:transaction, :debit, :credit, :membership, :attendance],
      order_by: [asc: coalesce(c.expires_on, c.when), asc_nulls_first: c.expires_on, asc: c.id]
      # order_by: [asc_nulls_last: c.expires_on, asc: c.when, asc: c.id]
    )
    |> Oas.Repo.all()

    {credits, total} = process_credits(credits)
    {
      credits |> Enum.reverse(),
      total,
    }
  end

  def get_global_credits() do
    members = from(m in Oas.Members.Member, where: true)
    |> Oas.Repo.all()
    members
    |> Enum.map(fn %{id: id} -> %{member_id: id} end)
    |> Enum.map(fn arg ->
      Oas.Credits.Credit2.get_credit_amount(arg) |> elem(1) |> Decimal.to_float()
    end)
    |> Enum.filter(fn amount -> amount > 0.0 end)
    |> Enum.sum()
  end
  def get_global_credits_to(to) do
    members = from(m in Oas.Members.Member, where: true)
    |> Oas.Repo.all()
    members
    |> Enum.map(fn %{id: id} -> %{member_id: id} end)
    |> Enum.map(fn arg ->
      Oas.Credits.Credit2.get_credit_amount(arg, %{now: to}) |> elem(1) |> Decimal.to_float()
    end)
    |> Enum.filter(fn amount -> amount > 0.0 end)
    |> Enum.sum()
  end

  def get_global_debt_to(to) do
    members = from(m in Oas.Members.Member, where: true)
    |> Oas.Repo.all()
    members
    |> Enum.map(fn %{id: id} -> %{member_id: id} end)
    |> Enum.map(fn arg ->
      get_credit_amount_to(arg, to) |> elem(1) |> Decimal.to_float()
    end)
    |> Enum.filter(fn amount -> amount < 0 end)
    |> Enum.sum()
  end

  def get_global_debt() do
    members = from(m in Oas.Members.Member, where: true)
    |> Oas.Repo.all()
    members
    |> Enum.map(fn %{id: id} -> %{member_id: id} end)
    |> Enum.map(fn arg ->
      get_credit_amount(arg) |> elem(1) |> Decimal.to_float()
    end)
    |> Enum.filter(fn amount -> amount < 0 end)
    |> Enum.sum()
  end

  defp deduct_debit(ledger, debit, opts \\ %{now: Date.utc_today()})
  defp deduct_debit([], debit, _opts) do
    [debit]
  end
  # Signs are the same, so can't deduct debt
  defp deduct_debit([%{amount: %Decimal{sign: sign}} = head | tail], %{amount: %Decimal{sign: sign}} = debit, opts ) do
    [head | deduct_debit(tail, debit, opts)]
  end
  defp deduct_debit([head | tail], debit, opts ) do
    # IO.puts("vvvvv")
    out = cond do
      # head has expired
      Map.get(head, :expires_on, nil) != nil and Date.after?(debit.when, head.expires_on) ->
        [head | tail] ++ [debit] # assume rest of the credits are expired as they are ordered
      Decimal.eq?(debit.amount, 0) ->
        [head | tail]
      # Debit amount is greater than the credit in the head, so remove
      Decimal.gte?(Decimal.abs(debit.amount), Decimal.abs(head.amount)) ->
        tail |> deduct_debit(%{debit | amount: Decimal.add(debit.amount, head.amount)}, opts)
      # debit amount is less than the credit in the head, so return the head with the amount removed
      Decimal.lt?(Decimal.abs(debit.amount), Decimal.abs(head.amount)) ->
        [%{head | amount: Decimal.add(head.amount, debit.amount)} | tail]
    end
    # IO.puts("^^^^^")
    out
  end

  defp process_credits(credits) do
    {trans, active_ledger} = credits |> Enum.map_reduce([], fn (credit, ledger) ->
      # IO.puts("vvvvvvvvvvvvvvvv")
      new_ledger = deduct_debit(ledger, credit)
      after_amount = Enum.reduce(new_ledger, Decimal.new("0.0"), fn %{amount: amount}, acc -> Decimal.add(acc, amount) end)
      out = {
        credit |> Map.put(:after_amount, after_amount),
        new_ledger
      }
      # out |> elem(0) |> IO.inspect()
      # IO.puts("^^^^^^^^^^^^^^^^")
      out
    end)

    {
      trans,
      Enum.reduce(active_ledger, Decimal.new("0"), fn %{amount: amount}, acc -> Decimal.add(acc, amount) end)
    }
  end

  def deduct_credit(from, member, amount, opts = %{now: now, disable_warning_emails: disable_warning_emails} \\ %{
    now: Date.utc_today(),
    changeset: false,
    attendance: nil,
    disable_warning_emails: false
  }) do
    if Decimal.positive?(amount) do
      raise "Oas.Credits.Credit.deduct_credit amount is positive"
    end

    {from, name} = case from do
      %Ecto.Changeset{} ->
        {from, from.data.__struct__ |> Module.split() |> List.last()}
      _item ->
        {
          from
          |> Oas.Repo.preload(:credit)
          |> Ecto.Changeset.change(),
          # from.__struct__.to_string() |> String.split(~r/\./) |> List.last
          from.__struct__ |> Module.split() |> List.last()
        }
    end

    out_changeset = from
    |> Ecto.Changeset.put_assoc(:credit, %Oas.Credits.Credit{
      what: "#{name}",
      when: now,
      amount: amount,
      who_member_id: member.id
    })

    if disable_warning_emails != true do
      Task.Supervisor.start_child(
        Oas.TaskSupervisor,
        fn ->
          Process.sleep(120_000)
          # Process.sleep(2) # DEBUG ONLY
          # Oas.TokenMailer.maybe_send_credits_warning(member)
          Oas.TokenMailer.warning_email(member, %{attendance: opts.attendance})
        end
      )
    end

    if (opts |> Map.get(:changeset, false)) do
      out_changeset
    else
      out = out_changeset |> Oas.Repo.update()
      out
    end
  end

  @deprecated "No longer used, use get_credit_amount"
  def get_credits(member, now \\ Date.utc_today()) do

    # """
    # # All credits that haven't expired
    # SELECT credits.*, credits.amount AS calc_credits from credits
    # WHERE expires_on IS null OR expires_on IS NOT null and '2025-02-02' <= expires_on
    # UNION ALL
    # # Credits that have expired, but have been used
    # SELECT credits.*, -SUM(credits.amount) AS calc_credits from credits
    # INNER JOIN credits_credits on credits.id = credits_credits.used_for_id
    # INNER JOIN credits AS income_credits ON credits_credits.uses_id = income_credits.id
    # WHERE income_credits.expires_on IS NOT null and '2025-02-02' > income_credits.expires_on
    # GROUP BY credits.id
    # """

    non_expired_subquery = from(c in Oas.Credits.Credit,
      where: (is_nil(c.expires_on) or (not is_nil(c.expires_on) and ^now <= c.expires_on))
        and c.who_member_id == ^member.id,
      select: {c, c.amount}
    )

    expired_subquery = from(c in Oas.Credits.Credit,
      inner_join: cc in assoc(c, :used_for_credits_credits),
      inner_join: ccc in assoc(cc, :uses),
      where: (not is_nil(c.expires_on) and ^now > c.expires_on)
        and c.who_member_id == ^member.id,
      group_by: c.id,
      select: {c, -sum(cc.amount)}
    )

    Ecto.Query.union_all(non_expired_subquery, ^expired_subquery)
    |> Oas.Repo.all()
  end



end
