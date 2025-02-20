import Ecto.Query, only: [from: 2]

defmodule Oas.Credits.Credits do
  use Ecto.Schema

  schema "credits" do
    field :what, :string
    field :amount, :decimal
    belongs_to :member, Oas.Members.Member, foreign_key: :who_member_id
    belongs_to :transaction, Oas.Transactions.Transaction, foreign_key: :transaction_id
    field :when, :date
    field :expires_on, :date

    many_to_many :uses, Oas.Credits.Credits,
      join_through: Oas.Credits.CreditsCredits,
      join_keys: [used_for_id: :id, uses_id: :id],
      unique: true

    has_many :uses_credits_credits, Oas.Credits.CreditsCredits, foreign_key: :used_for_id
    has_many :used_for_credits_credits, Oas.Credits.CreditsCredits, foreign_key: :uses_id

    timestamps()
  end

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

    non_expired_subquery = from(c in Oas.Credits.Credits,
      where: (is_nil(c.expires_on) or (not is_nil(c.expires_on) and ^now <= c.expires_on))
        and c.who_member_id == ^member.id,
      select: {c, c.amount}
    )

    expired_subquery = from(c in Oas.Credits.Credits,
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
