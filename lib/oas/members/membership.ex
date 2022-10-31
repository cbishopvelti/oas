defmodule Oas.Members.Membership do
  use Ecto.Schema
  import Ecto.Changeset

  schema "memberships" do
    belongs_to :member, Oas.Members.Member

    belongs_to :membership_period, Oas.Members.MembershipPeriod
    belongs_to :transaction, Oas.Transactions.Transaction

    field :notes, :string
    
    timestamps()
  end
end
