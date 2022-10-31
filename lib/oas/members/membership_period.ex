defmodule Oas.Members.MembershipPeriod do
  use Ecto.Schema
  import Ecto.Changeset

  schema "membership_periods" do
    field :name, :string
    field :from, :date
    field :to, :date
    field :value, :decimal

    has_many :memberships, Oas.Members.Membership

    timestamps()
  end
end