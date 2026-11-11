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
    |> unique_constraint()
  end

  # A member can only have one membership per period
  # (unique index memberships_member_id_membership_period_id_index).
  def unique_constraint(changeset) do
    Ecto.Changeset.unique_constraint(changeset, [:member_id, :membership_period_id],
      name: :memberships_member_id_membership_period_id_index,
      message: "already has a membership for this period"
    )
  end

  @doc """
  Adds `member` to `membership_period`, charging the period's fee unless the
  member is honorary.

  Returns `{:ok, membership}` or `{:error, changeset}`. The membership and its
  fee are saved together; callers in a transaction must roll back on error.
  """
  def add_membership(membership_period, member, %{now: now}) do
    Oas.Repo.transact(fn ->
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
    end)
  end

  def maybe_delete_membership(training, member) do
    # Get current membership periods which this training is in
    membership_periods = from(mp in Oas.Members.MembershipPeriod,
      inner_join: ms in assoc(mp, :memberships),
      where: ms.member_id == ^member.id and
        mp.from <= ^training.when and mp.to >= ^training.when,
      preload: [memberships: ms]
    ) |> Oas.Repo.all

    total_attendance = from(a in Oas.Trainings.Attendance,
      join: m in assoc(a, :member),
      where: m.id == ^member.id,
      select: count(m.id)
    ) |> Oas.Repo.one

    config = Oas.Settings.get_config()
    membership_periods |> Enum.map(fn membership_period ->
      # Does this member have any other trainings in that membership_period period?
      other_trainings_in_period = from(
        t in Oas.Trainings.Training,
        inner_join: a in assoc(t, :attendance),
        where: t.id != ^training.id and a.member_id == ^member.id and
          t.when >= ^membership_period.from and t.when <= ^membership_period.to
      )
      |> Oas.Repo.all

      # If there are other trainings in that membership period, don't delete the membership
      total_attendance = total_attendance - 1 # This is called before this attendance has been deleted.
      if (
        other_trainings_in_period |> length() > 0 and # true
        total_attendance > config.temporary_trainings # false Not a temporary member
      ) do
        nil
      else
        [_membership] = membership_period.memberships
        nil
      end
    end)
  end
end
