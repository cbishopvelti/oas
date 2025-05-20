import Ecto.Query, only: [from: 2]

defmodule Oas.Members.Membership do
  use Ecto.Schema

  schema "memberships" do
    belongs_to :member, Oas.Members.Member

    belongs_to :membership_period, Oas.Members.MembershipPeriod
    belongs_to :transaction, Oas.Transactions.Transaction

    field :notes, :string

    has_one :credit, Oas.Credits.Credit, foreign_key: :membership_id

    timestamps()
  end

  def changeset(struct, params) do
    struct
    |> Ecto.Changeset.cast(params, [:member_id, :membership_period_id])
  end

  def add_membership(membership_period, member, %{now: now}) do
    IO.puts("101")
    changeset = %Oas.Members.Membership{}
    |> changeset(%{
      member_id: member.id,
      membership_period_id: membership_period.id
    })

    changeset = if (!member.honorary_member) do
      changeset
      |> Oas.Credits.Credit.deduct_credit(member, Decimal.sub(0, membership_period.value), %{now: now, changeset: true})
    else
      changeset
    end

    Oas.Repo.insert(changeset)
    nil
  end

  def maybe_delete_membership(training, member) do
    # Get current membership periods which this training is in
    membership_periods = from(mp in Oas.Members.MembershipPeriod,
      inner_join: ms in assoc(mp, :memberships),
      where: ms.member_id == ^member.id and
        mp.from <= ^training.when and mp.to >= ^training.when,
      preload: [memberships: ms]
    ) |> Oas.Repo.all

    membership_periods |> Enum.map(fn membership_period ->
      # Does this member have any other trainings in that membership_period period?
      other_trainings_in_period = from(
        t in Oas.Trainings.Training,
        inner_join: a in assoc(t, :attendance),
        where: t.id != ^training.id and a.member_id == ^member.id and
          t.when >= ^membership_period.from and t.when <= ^membership_period.to
      )
      |>Oas.Repo.all

      # If there are other trainings in that membership period, don't delete the membership
      if (other_trainings_in_period |> length() > 0) do
        nil
      else
        [membership] = membership_period.memberships
        Oas.Repo.delete(membership)
        nil
      end
    end)
  end
end
