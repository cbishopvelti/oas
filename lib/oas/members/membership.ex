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

  @doc """
  Called when `member`'s attendance of `training` is being removed (before the
  attendance row is deleted). Deletes the memberships that booking earned the
  member, which refunds their fee (the fee credit is deleted with its
  membership), unless the member's remaining bookings still earn them.

  Mirrors `Oas.Attendance.add_attendance`, so it leaves alone:
    * everything when credits are off or the training doesn't count towards
      membership;
    * memberships paid for by a bank transaction;
    * a period the member has another counting booking in, as long as they
      would still be made a member for it (honorary, a member of another
      period, or past the temporary trainings limit).

  Raises if a delete fails, so the surrounding transaction rolls back.
  """
  def maybe_delete_membership(training, member) do
    config = Oas.Settings.get_config()

    if config.credits and training.exempt_membership_count != true do
      # Memberships (with their period) this training falls in
      memberships = from(ms in Oas.Members.Membership,
        inner_join: mp in assoc(ms, :membership_period),
        where: ms.member_id == ^member.id and is_nil(ms.transaction_id) and
          mp.from <= ^training.when and mp.to >= ^training.when,
        preload: [membership_period: mp]
      ) |> Oas.Repo.all()

      if memberships != [] do
        # The member's other bookings that count towards membership. This is
        # called before the attendance is deleted, so leave its training out.
        other_trainings = from(t in Oas.Trainings.Training,
          inner_join: a in assoc(t, :attendance),
          where: a.member_id == ^member.id and t.id != ^training.id and
            (is_nil(t.exempt_membership_count) or t.exempt_membership_count == ^false),
          select: t.when
        ) |> Oas.Repo.all()

        membership_ids = Enum.map(memberships, & &1.id)
        member_of_another_period = from(ms in Oas.Members.Membership,
          where: ms.member_id == ^member.id and ms.id not in ^membership_ids
        ) |> Oas.Repo.exists?()

        still_joins = member.honorary_member == true or member_of_another_period or
          length(other_trainings) > config.temporary_trainings

        Enum.each(memberships, fn membership ->
          period = membership.membership_period
          other_training_in_period = Enum.any?(other_trainings, fn when1 ->
            Date.compare(when1, period.from) != :lt and Date.compare(when1, period.to) != :gt
          end)

          if !(other_training_in_period and still_joins) do
            Oas.Repo.delete!(membership)
          end
        end)
      end
    end

    :ok
  end
end
