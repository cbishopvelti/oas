defmodule OasWeb.Schema.UserBookingsPriceTest do
  @moduledoc """
  My bookings must show the amount override of the venue time for the
  event's day of week, the same amount booking charges, not the amount of
  whichever time happens to come first.
  """
  use Oas.DataCase, async: false

  @query """
  query { user_bookings { id price } }
  """

  setup do
    {:ok, _} = Oas.TestConfig.update_config(%{credits: true, enable_booking: true}, [:credits, :enable_booking])

    member = Oas.MembersFixtures.member_fixture()

    venue =
      %Oas.Trainings.TrainingWhere{}
      |> Oas.Trainings.TrainingWhere.changeset(%{name: "test venue #{System.unique_integer()}", credit_amount: 5})
      |> Repo.insert!()

    # A future Wednesday. The venue has time overrides for Monday, Friday and
    # Wednesday, inserted in that order, so Wednesday's is neither first by
    # day nor first by insertion.
    from_date = Date.add(Date.utc_today(), 7)
    when1 = Date.add(from_date, rem(3 - Date.day_of_week(from_date) + 7, 7))

    for {day, amount} <- [{1, "3"}, {5, "9"}, {3, "7"}] do
      Repo.insert!(%Oas.Trainings.TrainingWhereTime{
        training_where_id: venue.id,
        day_of_week: day,
        start_time: ~T[19:00:00],
        credit_amount: Decimal.new(amount)
      })
    end

    training =
      %Oas.Trainings.Training{
        when: when1,
        notes: "",
        training_where_id: venue.id,
        is_active: true,
        exempt_membership_count: true,
        disable_warning_emails: true
      }
      |> Repo.insert!()

    %{member: member, training: training}
  end

  defp price(member, training) do
    {:ok, %{data: %{"user_bookings" => bookings}}} =
      Absinthe.run(@query, OasWeb.Schema, context: %{current_member: %{member | is_active: true}})

    bookings |> Enum.find(&(&1["id"] == training.id)) |> Map.get("price")
  end

  test "shows the day's time override before booking, and it matches the charge", ctx do
    assert Decimal.equal?(Decimal.new(price(ctx.member, ctx.training)), Decimal.new("7"))

    {:ok, _} =
      Oas.Attendance.add_attendance(
        %{member_id: ctx.member.id, training_id: ctx.training.id},
        %{inserted_by_member_id: ctx.member.id}
      )

    credit =
      from(c in Oas.Credits.Credit,
        join: a in assoc(c, :attendance),
        where: a.training_id == ^ctx.training.id and a.member_id == ^ctx.member.id
      )
      |> Repo.one!()

    assert Decimal.equal?(Decimal.abs(credit.amount), Decimal.new("7"))
    assert Decimal.equal?(Decimal.new(price(ctx.member, ctx.training)), Decimal.new("7"))
  end
end
