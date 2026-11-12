defmodule Oas.NonUkSocietyTest do
  @moduledoc """
  End-to-end check for multi-society Phase 2: a society in New York that
  charges in US dollars. Everything is set through `Oas.Settings`, with no
  config changes or redeploy, and the booking cutoff, credit expiry, emails
  and the public settings query all follow.
  """
  use Oas.DataCase

  import Ecto.Query, only: [from: 2]
  import Swoosh.TestAssertions

  alias Oas.Settings
  alias Oas.Trainings.{Training, TrainingWhere, TrainingWhereTime}

  @zone "America/New_York"
  @name "Brooklyn Acro Club"

  setup do
    on_exit(fn -> Settings.put_test_utc_now(nil) end)

    {:ok, _} =
      Settings.update_config(
        %{name: @name, time_zone: @zone, currency: "USD", phone_country_code: "1"},
        [:name, :time_zone, :currency, :phone_country_code]
      )

    :ok
  end

  defp utc(iso) do
    {:ok, dt, 0} = DateTime.from_iso8601(iso)
    dt
  end

  test "a New York society paying in dollars" do
    member = Oas.MembersFixtures.member_fixture()

    # 20:30 on Tuesday 10 Nov in New York, which is already Wednesday in UTC
    # (and in London).
    Settings.put_test_utc_now(utc("2026-11-11T01:30:00Z"))
    assert Settings.today() == ~D[2026-11-10]

    # ---- booking cutoff ----
    # A 22:00 local session that closes for booking an hour before it starts.
    where = %TrainingWhere{name: "Brooklyn #{System.unique_integer()}"} |> Repo.insert!()

    %TrainingWhereTime{
      training_where_id: where.id,
      day_of_week: Date.day_of_week(~D[2026-11-10]),
      start_time: ~T[22:00:00],
      end_time: ~T[23:30:00],
      booking_offset: "-PT1H"
    }
    |> Repo.insert!()

    training =
      %Training{
        training_where_id: where.id,
        when: ~D[2026-11-10],
        is_active: true,
        commitment: false
      }
      |> Repo.insert!()

    # Today's session is still listed, and its cutoff is 21:00 EST = 02:00 UTC.
    # Under London time the cutoff would be 21:00 UTC on the 10th.
    assert {:ok, %{data: %{"user_bookings" => bookings}}} =
             Absinthe.run("{ user_bookings { id when booking_cutoff } }", OasWeb.Schema,
               context: %{current_member: %{member | is_active: true}}
             )

    assert %{"when" => "2026-11-10", "booking_cutoff" => cutoff} =
             Enum.find(bookings, &(&1["id"] == training.id))

    assert {:ok, cutoff_utc, 0} = DateTime.from_iso8601(cutoff)
    assert cutoff_utc == utc("2026-11-11T02:00:00Z")

    # A booking made earlier in the day can be undone up to the cutoff, not after.
    attendance = %{inserted_at: ~N[2026-11-10 15:00:00]}
    training = Repo.preload(training, training_where: :training_where_time)

    twt =
      TrainingWhereTime.find_training_where_time(
        training,
        training.training_where.training_where_time
      )

    assert TrainingWhereTime.can_undo?(attendance, training, twt, utc("2026-11-11T01:59:59Z"))
    refute TrainingWhereTime.can_undo?(attendance, training, twt, utc("2026-11-11T02:00:00Z"))

    # ---- credit expiry ----
    %Oas.Transactions.Transaction{}
    |> Ecto.Changeset.cast(
      %{
        who: member.name,
        who_member_id: member.id,
        what: "Credit",
        amount: Decimal.new("5"),
        when: ~D[2026-01-01],
        type: "INCOMING",
        my_reference: "non-uk"
      },
      [:who, :who_member_id, :what, :amount, :when, :type, :my_reference]
    )
    |> Oas.Credits.Credit.doCredit(%{amount: Decimal.new("5")})
    |> Repo.insert!()

    expires_on =
      from(c in Oas.Credits.Credit, where: c.who_member_id == ^member.id, select: c.expires_on)
      |> Repo.one!()

    balance = fn ->
      {_, total} = Oas.Credits.Credit2.get_credit_amount(%{member_id: member.id})
      Decimal.to_float(total)
    end

    # 23:30 New York time the night before expiry: already expires_on in UTC,
    # but the credit is still good.
    Settings.put_test_utc_now(
      DateTime.new!(Date.add(expires_on, -1), ~T[23:30:00], @zone)
      |> DateTime.shift_zone!("Etc/UTC")
    )

    assert balance.() == 5.0

    # New York midnight: gone.
    Settings.put_test_utc_now(
      DateTime.new!(expires_on, ~T[00:00:00], @zone)
      |> DateTime.shift_zone!("Etc/UTC")
    )

    assert balance.() == 0.0

    # ---- email ----
    # Subject and sender name from the name setting. The sender address comes
    # from the mailer config (MAIL_FROM_ADDRESS).
    {:ok, _} = Oas.testEmail("member@example.com")
    {_sender_name, sender_address} = Application.get_env(:oas, Oas.TokenMailer)[:from]

    assert_email_sent(fn email ->
      assert email.subject == "#{@name} test"
      assert email.from == {@name, sender_address}
      true
    end)

    assert Settings.society_slug() == "brooklyn-acro-club"

    # ---- public settings ----
    assert {:ok, %{data: %{"public_config_config" => public}}} =
             Absinthe.run("{ public_config_config { name time_zone currency } }", OasWeb.Schema,
               context: %{}
             )

    assert public == %{"name" => @name, "time_zone" => @zone, "currency" => "USD"}
  end
end
