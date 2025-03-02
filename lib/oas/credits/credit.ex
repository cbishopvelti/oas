import Ecto.Query, only: [from: 2]

defmodule Oas.Credits.Credit do
  use Ecto.Schema
  import Ecto.Changeset

  schema "credits" do
    field :what, :string
    field :amount, :decimal
    belongs_to :member, Oas.Members.Member, foreign_key: :who_member_id
    belongs_to :transaction, Oas.Transactions.Transaction, foreign_key: :transaction_id
    field :when, :date
    field :expires_on, :date

    many_to_many :uses, Oas.Credits.Credit,
      join_through: Oas.Credits.CreditsCredits,
      join_keys: [used_for_id: :id, uses_id: :id],
      unique: true

    has_many :uses_credits_credits, Oas.Credits.CreditsCredits, foreign_key: :used_for_id
    has_many :used_for_credits_credits, Oas.Credits.CreditsCredits, foreign_key: :uses_id

    timestamps()
  end

  defp validate_transaction(changeset) do
    cond do
      Decimal.gt?(get_field(changeset, :amount), 0) && !get_field(changeset, :transaction_id) ->
        add_error(changeset, :transaction_id, "There must be a transaction")
      true -> changeset
    end
  end

  def changeset(changeset, params \\ %{}) do
    changeset
    |> cast(params, [
      :what, :who_member_id, :amount,
      :when, :expires_on
    ], empty_values: [[], nil])
  end

  def doCredit(changeset, nil) do
    out = case get_assoc(changeset, :credit) do
      nil -> %Oas.Credits.Credit{}
      assoc ->
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
        credit = out
        |> changeset(%{
          amount: amount,
          # who_member_id: get_assoc(changeset, :credit) |> List.first() |> get_field()
          who_member_id: get_field(changeset, :who_member_id),
          what: get_field(changeset, :what),
          when: get_field(changeset, :when),
          expires_on: get_field(changeset, :when) |> Date.add(config.token_expiry_days)
        })
    end

    Ecto.Changeset.put_assoc(changeset, :credit, out)
  end

  def get_credit_amount(%{member_id: member_id}) do
    credits = from(c in Oas.Credits.Credit,
      where: c.who_member_id == ^member_id,
      preload: [:transaction],
      order_by: [asc: coalesce(c.expires_on, c.when), asc_nulls_first: c.expires_on, asc: c.id]
    )
    |> Oas.Repo.all()

    {credits, total} = process_credits(credits)
    {
      credits |> Enum.reverse(),
      total,
    }
  end

  def deduct_debit(ledger, debit, opts \\ %{now: Date.utc_today()})
  def deduct_debit([], debit, opts) do
    [debit]
  end
  # Signs are the same, so can't deduct debt
  def deduct_debit([%{amount: %Decimal{sign: sign}} = head | tail], %{amount: %Decimal{sign: sign}} = debit, opts ) do
    [head | deduct_debit(tail, debit, opts)]
  end
  def deduct_debit([head | tail], debit, opts ) do
    IO.puts("vvvvv")
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
    IO.puts("^^^^^")
    out
  end

  def process_credits(credits) do
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


  @deprecated
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
