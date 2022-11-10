import Ecto.Query, only: [from: 2]

defmodule Oas.Members.MembershipPeriod do
  use Ecto.Schema
  import Ecto.Changeset

  schema "membership_periods" do
    field :name, :string
    field :from, :date
    field :to, :date
    field :value, :decimal

    has_many :memberships, Oas.Members.Membership

    many_to_many :members, Oas.Members.Member, join_through: Oas.Members.Membership

    timestamps()
  end

  def getThisOrNextMembershipPeriod(when1) do 
    membershipPeriod = from(mp in Oas.Members.MembershipPeriod,
      where: (mp.from <= ^when1 and mp.to > ^Date.add(when1, 31)) or
        (mp.from <= ^Date.add(when1, 31) and mp.to > ^when1),
      limit: 1
    )

    |> Oas.Repo.one
  end
end