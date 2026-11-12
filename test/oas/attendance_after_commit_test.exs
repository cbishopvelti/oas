defmodule Oas.AttendanceAfterCommitTest do
  @moduledoc """
  Emails and subscription publishes caused by a booking, an undo or a
  membership must only go out once the write is committed, and not at all when
  it rolls back.

  `Oas.Mail.Background.run/2` and `Absinthe.Subscription.publish/3` are mocked
  to report each call to the test, along with whether a database transaction
  was still open when it was made.
  """
  # Not async: Mock replaces modules globally.
  use Oas.DataCase, async: false

  import Mock

  # Total price of the pricing instance, spread over the trainings attended.
  @lua "return 10"

  setup do
    {:ok, _} = Oas.TestConfig.update_config(%{credits: true}, [:credits])

    # No credit, so any charge takes the member below zero and warrants a warning.
    member = Oas.MembersFixtures.member_fixture()

    {:ok, pricing} =
      %Oas.Pricing.Pricing{name: "test pricing #{System.unique_integer()}"} |> Repo.insert()

    {:ok, pricing_instance} =
      %Oas.Pricing.PricingInstance{
        name: "test instance",
        is_active: true,
        blockly_lua: @lua,
        pricing_id: pricing.id
      }
      |> Repo.insert()

    {:ok, venue} =
      %Oas.Trainings.TrainingWhere{}
      |> Oas.Trainings.TrainingWhere.changeset(%{name: "test venue #{System.unique_integer()}", credit_amount: 5})
      |> Repo.insert()

    %{member: member, venue: venue, pricing_instance: pricing_instance}
  end

  defp training(ctx, attrs \\ %{}) do
    %Oas.Trainings.Training{
      when: Date.new!(2025, 10, 3),
      notes: "",
      training_where_id: ctx.venue.id,
      exempt_membership_count: true
    }
    |> Map.merge(attrs)
    |> Repo.insert!()
  end

  defp bundle_training(ctx, day, attrs \\ %{}) do
    training(
      ctx,
      Map.merge(%{when: Date.new!(2025, 10, day), pricing_instance_id: ctx.pricing_instance.id}, attrs)
    )
  end

  defp add(member, training) do
    Oas.Attendance.add_attendance(
      %{member_id: member.id, training_id: training.id},
      %{inserted_by_member_id: member.id}
    )
  end

  defp attendance(member, training) do
    from(a in Oas.Trainings.Attendance,
      where: a.member_id == ^member.id and a.training_id == ^training.id
    )
    |> Repo.one()
  end

  # Reports side effects to the test instead of performing them.
  defp side_effect_mocks(extra \\ []) do
    test = self()

    [
      {Oas.Mail.Background, [:passthrough],
       run: fn _fun, opts ->
         # Only the low-credit warning is delayed; the token one is not.
         kind = if Keyword.has_key?(opts, :delay), do: :credit_warning, else: :token_warning
         send(test, {:mail_queued, kind, Oas.Repo.in_transaction?()})
         {:ok, test}
       end},
      {Absinthe.Subscription, [:passthrough],
       publish: fn _endpoint, _payload, topics ->
         send(test, {:published, topics, Oas.Repo.in_transaction?()})
         :ok
       end}
      | extra
    ]
  end

  defp credit_error(changeset) do
    {:error, Ecto.Changeset.add_error(changeset, :amount, "forced credit write failure")}
  end

  # Makes Repo.update/1 fail for credit changesets only. The credit of a new
  # attendance is written through the attendance, so that still goes through;
  # re-spreading the price over the member's other attendances fails.
  defp repo_failing_respread do
    {Oas.Repo, [:passthrough],
     update: fn
       %Ecto.Changeset{data: %Oas.Credits.Credit{}} = changeset -> credit_error(changeset)
       changeset -> :meck.passthrough([changeset])
     end}
  end

  defp refute_side_effects do
    refute_received {:mail_queued, _, _}
    refute_received {:published, _, _}
  end

  defp flush_side_effects do
    receive do
      {:mail_queued, _, _} -> flush_side_effects()
      {:published, _, _} -> flush_side_effects()
    after
      0 -> :ok
    end
  end

  describe "deduct_credit" do
    test "writes the credit without queuing an email", ctx do
      training = training(ctx)
      attendance = %Oas.Trainings.Attendance{member_id: ctx.member.id, training_id: training.id} |> Repo.insert!()

      with_mocks side_effect_mocks() do
        assert {:ok, _} =
                 Oas.Credits.Credit.deduct_credit(attendance, ctx.member, Decimal.new("-5"), %{now: training.when})

        assert %Ecto.Changeset{} =
                 Oas.Credits.Credit.deduct_credit(
                   %Oas.Members.Membership{} |> Ecto.Changeset.change(),
                   ctx.member,
                   Decimal.new("-5"),
                   %{now: training.when, changeset: true}
                 )
      end

      refute_side_effects()
    end
  end

  describe "add_attendance" do
    test "sends the low-credit warning email after a committed booking", ctx do
      Application.put_env(:oas, :warning_email_delay, 0)
      on_exit(fn -> Application.delete_env(:oas, :warning_email_delay) end)

      assert {:ok, %{success: true}} = add(ctx.member, training(ctx))

      email = ctx.member.email
      assert_receive {:email, %Swoosh.Email{to: [{_, ^email}], text_body: body}}, 2_000
      assert body =~ "You have run out of credits"
      refute_receive {:email, _}, 200
    end

    test "queues the warning and publishes only after the commit", ctx do
      training_a = bundle_training(ctx, 3)
      training_b = bundle_training(ctx, 4, %{limit: 1})
      member_id = ctx.member.id
      training_a_id = training_a.id

      with_mocks side_effect_mocks() do
        assert {:ok, _} = add(ctx.member, training_a)
        # Nothing to re-spread and no limit: only the emails
        assert_received {:mail_queued, :token_warning, false}
        assert_received {:mail_queued, :credit_warning, false}
        refute_side_effects()

        assert {:ok, _} = add(ctx.member, training_b)
        # training_b is now full
        assert_received {:published, [user_attendance_attendance: "global"], false}
        # training_a's credit went from 10 to 5
        assert_received {:published, [user_attendance_attendance: ^member_id], false}
        assert_received {:published, [attendance_attendance: ^training_a_id], false}
        assert_received {:mail_queued, :token_warning, false}
        assert_received {:mail_queued, :credit_warning, false}
        refute_side_effects()
      end
    end

    test "queues no credit warning when the training has warning emails turned off", ctx do
      with_mocks side_effect_mocks() do
        assert {:ok, _} = add(ctx.member, training(ctx, %{disable_warning_emails: true}))
      end

      refute_side_effects()
    end

    test "sends and publishes nothing when the booking is refused because the training is full", ctx do
      training = training(ctx, %{limit: 1})
      other = Oas.MembersFixtures.member_fixture()

      with_mocks side_effect_mocks() do
        assert {:ok, _} = add(other, training)
        flush_side_effects()

        assert {:error, _} = catch_throw(add(ctx.member, training))
      end

      assert attendance(ctx.member, training) == nil
      refute_side_effects()
    end

    test "sends and publishes nothing when the booking rolls back after its credit was written", ctx do
      training_a = bundle_training(ctx, 3)
      training_b = bundle_training(ctx, 4, %{limit: 1})
      {:ok, _} = add(ctx.member, training_a)
      flush_mailbox()

      # training_b's own credit is deducted, then re-spreading training_a fails
      with_mocks side_effect_mocks([repo_failing_respread()]) do
        assert {:error, _} = catch_throw(add(ctx.member, training_b))
      end

      assert attendance(ctx.member, training_b) == nil
      refute_side_effects()
    end

    test "sends and publishes nothing when the booking raises", ctx do
      training = training(ctx, %{limit: 1})

      Repo.query!("""
      CREATE TRIGGER test_fail_credit_insert
      BEFORE INSERT ON credits
      BEGIN
        SELECT RAISE(ABORT, 'forced credit write failure');
      END
      """)

      with_mocks side_effect_mocks() do
        assert_raise Exqlite.Error, fn -> add(ctx.member, training) end
      end

      assert attendance(ctx.member, training) == nil
      refute_side_effects()
    end
  end

  describe "a publish that fails after the commit" do
    import ExUnit.CaptureLog

    test "does not fail a booking that is already saved, and the warning is still queued", ctx do
      training = training(ctx, %{limit: 1})
      test = self()

      mocks = [
        {Oas.Mail.Background, [:passthrough],
         run: fn _fun, _opts ->
           send(test, :mail_queued)
           {:ok, test}
         end},
        {Absinthe.Subscription, [:passthrough],
         publish: fn _endpoint, _payload, _topics -> raise "pubsub is down" end}
      ]

      log =
        capture_log(fn ->
          with_mocks mocks do
            assert {:ok, %{success: true}} = add(ctx.member, training)
          end
        end)

      assert log =~ "pubsub is down"
      assert attendance(ctx.member, training)
      # The token warning and the low-credit warning
      assert_received :mail_queued
      assert_received :mail_queued
    end
  end

  describe "add_attendance with a membership fee" do
    setup ctx do
      {:ok, _} = Oas.TestConfig.update_config(%{temporary_trainings: 0}, [:temporary_trainings])

      period =
        %Oas.Members.MembershipPeriod{
          name: "2025",
          from: ~D[2025-01-01],
          to: ~D[2025-12-31],
          value: Decimal.new("20")
        }
        |> Repo.insert!()

      %{period: period, training: training(ctx, %{exempt_membership_count: false})}
    end

    defp membership_count(member) do
      from(m in Oas.Members.Membership, where: m.member_id == ^member.id, select: count(m.id))
      |> Repo.one()
    end

    test "queues one credit warning for the booking and its membership fee together", ctx do
      with_mocks side_effect_mocks() do
        assert {:ok, _} = add(ctx.member, ctx.training)
      end

      assert membership_count(ctx.member) == 1
      assert_received {:mail_queued, :token_warning, false}
      assert_received {:mail_queued, :credit_warning, false}
      refute_side_effects()
    end

    test "still warns about the membership fee when the training has warning emails turned off", ctx do
      training = training(ctx, %{exempt_membership_count: false, disable_warning_emails: true})

      with_mocks side_effect_mocks() do
        assert {:ok, _} = add(ctx.member, training)
      end

      assert membership_count(ctx.member) == 1
      assert_received {:mail_queued, :credit_warning, false}
      refute_side_effects()
    end

    test "sends nothing when the booking rolls back after the membership fee was written", ctx do
      fail_attendance_credit =
        {Oas.Pricing.CalcAttendance, [:passthrough],
         apply: fn _training, attendance, _member ->
           attendance |> Ecto.Changeset.change() |> credit_error()
         end}

      with_mocks side_effect_mocks([fail_attendance_credit]) do
        assert {:error, _} = catch_throw(add(ctx.member, ctx.training))
      end

      assert attendance(ctx.member, ctx.training) == nil
      assert membership_count(ctx.member) == 0
      refute_side_effects()
    end

    @mutation """
    mutation ($membership_period_id: Int!, $member_id: Int!) {
      add_membership(membership_period_id: $membership_period_id, member_id: $member_id) { success }
    }
    """

    defp add_membership(member, period) do
      Absinthe.run(@mutation, OasWeb.Schema,
        variables: %{"membership_period_id" => period.id, "member_id" => member.id},
        context: %{current_member: %{is_admin: true}}
      )
    end

    test "the admin add_membership mutation queues the warning once the fee is saved", ctx do
      with_mocks side_effect_mocks() do
        assert {:ok, %{data: %{"add_membership" => %{"success" => true}}}} =
                 add_membership(ctx.member, ctx.period)
      end

      assert membership_count(ctx.member) == 1
      assert_received {:mail_queued, :credit_warning, false}
      refute_side_effects()
    end

    test "the admin add_membership mutation sends the low-credit warning email", ctx do
      Application.put_env(:oas, :warning_email_delay, 0)
      on_exit(fn -> Application.delete_env(:oas, :warning_email_delay) end)

      assert {:ok, %{data: %{"add_membership" => %{"success" => true}}}} =
               add_membership(ctx.member, ctx.period)

      # This email used to crash in the background task: a membership has no attendance.
      email = ctx.member.email
      assert_receive {:email, %Swoosh.Email{to: [{_, ^email}], text_body: body}}, 2_000
      assert body =~ "You have run out of credits"
      assert :ets.lookup(:global_warnings, Oas.Mail.Background.warning_key()) == []
    end

    test "the admin add_membership mutation queues nothing for an honorary member", ctx do
      member = ctx.member |> Ecto.Changeset.change(honorary_member: true) |> Repo.update!()

      with_mocks side_effect_mocks() do
        assert {:ok, %{data: %{"add_membership" => %{"success" => true}}}} =
                 add_membership(member, ctx.period)
      end

      refute_side_effects()
    end
  end

  describe "delete_attendance" do
    setup ctx do
      training_a = bundle_training(ctx, 3, %{disable_warning_emails: true})
      training_b = bundle_training(ctx, 4, %{disable_warning_emails: true, limit: 1})
      {:ok, _} = add(ctx.member, training_a)
      {:ok, _} = add(ctx.member, training_b)
      flush_mailbox()

      %{training_a: training_a, training_b: training_b}
    end

    test "publishes only after the commit", ctx do
      %{id: id} = attendance(ctx.member, ctx.training_b)
      member_id = ctx.member.id
      training_a_id = ctx.training_a.id

      with_mocks side_effect_mocks() do
        assert {:ok, %{success: true}} = Oas.Attendance.delete_attendance(%{attendance_id: id})
      end

      # training_b has a space again
      assert_received {:published, [user_attendance_attendance: "global"], false}
      # training_a's credit went from 5 back to 10
      assert_received {:published, [user_attendance_attendance: ^member_id], false}
      assert_received {:published, [attendance_attendance: ^training_a_id], false}
      refute_side_effects()
    end

    test "publishes nothing when the delete rolls back", ctx do
      %{id: id} = attendance(ctx.member, ctx.training_b)

      with_mocks side_effect_mocks([repo_failing_respread()]) do
        assert {:error, _} = Oas.Attendance.delete_attendance(%{attendance_id: id})
      end

      assert %{id: ^id} = attendance(ctx.member, ctx.training_b)
      refute_side_effects()
    end
  end

  describe "inside an outer Oas.AfterCommit.transact" do
    test "a booking's emails and publishes wait for the outer commit", ctx do
      training = training(ctx, %{limit: 1})

      with_mocks side_effect_mocks() do
        assert {:ok, :done} =
                 Oas.AfterCommit.transact(fn ->
                   assert {:ok, _} = add(ctx.member, training)
                   refute_side_effects()
                   {:ok, :done}
                 end)
      end

      assert_received {:published, [user_attendance_attendance: "global"], false}
      assert_received {:mail_queued, :token_warning, false}
      assert_received {:mail_queued, :credit_warning, false}
      refute_side_effects()
    end

    test "nothing goes out when the outer transaction rolls back after a booking and an undo", ctx do
      training_a = training(ctx, %{limit: 1})
      training_b = training(ctx, %{limit: 1, when: ~D[2025-10-04]})
      {:ok, _} = add(ctx.member, training_a)
      %{id: id} = attendance(ctx.member, training_a)
      flush_mailbox()

      with_mocks side_effect_mocks() do
        assert {:error, :later_step_failed} =
                 Oas.AfterCommit.transact(fn ->
                   assert {:ok, _} = Oas.Attendance.delete_attendance(%{attendance_id: id})
                   assert {:ok, _} = add(ctx.member, training_b)
                   {:error, :later_step_failed}
                 end)
      end

      assert %{id: ^id} = attendance(ctx.member, training_a)
      assert attendance(ctx.member, training_b) == nil
      refute_side_effects()
    end
  end

  describe "merge_members!" do
    setup ctx do
      training_a = bundle_training(ctx, 3, %{limit: 1})
      training_b = bundle_training(ctx, 4)
      {:ok, _} = add(ctx.member, training_a)
      {:ok, _} = add(ctx.member, training_b)
      flush_mailbox()

      %{to: Oas.MembersFixtures.member_fixture(), training_a: training_a, training_b: training_b}
    end

    test "publishes for the moved attendances go out after the merge commits, with no emails", ctx do
      with_mocks side_effect_mocks() do
        assert [_, _] = Oas.Members.merge_members!(ctx.member.id, ctx.to.id, inserted_by_member_id: ctx.to.id)
      end

      # A merge sends the new member no warning emails
      refute_received {:mail_queued, _, _}
      # training_a had a space, then was full again
      assert_received {:published, [user_attendance_attendance: "global"], false}
      assert_received {:published, [user_attendance_attendance: "global"], false}
      # Everything else also waited for the commit
      refute_received {:published, _, true}
    end

    test "nothing goes out when the merge rolls back partway", ctx do
      # Re-adding training_b for the target fails, after training_a has been
      # moved. Created inside the test's sandbox transaction, so dropped after.
      Repo.query!("""
      CREATE TRIGGER test_fail_merge_insert
      BEFORE INSERT ON attendance
      WHEN NEW.member_id = #{ctx.to.id} AND NEW.training_id = #{ctx.training_b.id}
      BEGIN
        SELECT RAISE(ABORT, 'forced attendance insert failure');
      END
      """)

      with_mocks side_effect_mocks() do
        assert_raise Exqlite.Error, ~r/forced attendance insert failure/, fn ->
          Oas.Members.merge_members!(ctx.member.id, ctx.to.id, inserted_by_member_id: ctx.to.id)
        end
      end

      assert attendance(ctx.to, ctx.training_a) == nil
      assert attendance(ctx.member, ctx.training_a) != nil
      refute_side_effects()
    end
  end

  # Drops emails from real background tasks started in setup, outside the mocks.
  defp flush_mailbox do
    receive do
      _ -> flush_mailbox()
    after
      0 -> :ok
    end
  end
end
