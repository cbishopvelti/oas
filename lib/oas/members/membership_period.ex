import Ecto.Query, only: [from: 2, where: 3]

defmodule Oas.Members.MembershipPeriod do
  use Ecto.Schema

  schema "membership_periods" do
    field :name, :string
    field :from, :date
    field :to, :date
    field :value, :decimal

    has_many :memberships, Oas.Members.Membership

    many_to_many :members, Oas.Members.Member, join_through: Oas.Members.Membership

    timestamps()
  end

  def getThisOrNextMembershipPeriod(when1, who_member_id, amount) do
    query =
      from(mp in Oas.Members.MembershipPeriod,
        as: :membership_periods,
        where:
          (mp.from <= ^when1 and ^when1 <= mp.to and mp.value == ^amount) or
            (mp.from <= ^Date.add(when1, 31) and ^when1 <= mp.to and mp.value == ^amount),
        order_by: [asc: mp.from],
        limit: 1
      )
      |> (&(case who_member_id do
              nil ->
                &1

              who_member_id ->
                where(
                  &1,
                  [mp],
                  not exists(
                    from(
                      m in Oas.Members.Member,
                      inner_join: mp in assoc(m, :membership_periods),
                      where: m.id == ^who_member_id and mp.id == parent_as(:membership_periods).id
                    )
                  )
                )
            end)).()

    out = query |> Oas.Repo.one()
    out
  end
end
