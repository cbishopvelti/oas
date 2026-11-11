defmodule Oas.MailTest do
  # Not async: the routing test swaps the mailer config for the whole app.
  use Oas.DataCase, async: false

  import Swoosh.TestAssertions

  defmodule TaggingAdapter do
    # Tells the test process which mailer an email left through.
    use Swoosh.Adapter

    @impl true
    def deliver(email, config) do
      send(self(), {:sent_via, config[:tag], email})
      {:ok, %{}}
    end
  end

  @from Application.compile_env(:oas, Oas.TokenMailer)[:from]

  setup do
    {:ok, _} = Oas.Settings.update_config(%{name: "Test Acro"}, [:name])
    :ok
  end

  describe "the four kinds of email" do
    test "member account email" do
      member = Oas.MembersFixtures.member_fixture()

      {:ok, _} =
        Oas.Members.MemberNotifier.deliver_reset_password_instructions(member, "https://x/reset")

      assert_email_sent(fn email ->
        assert email.to == [{"", member.email}]
        assert email.from == @from
        assert email.subject == "Reset password instructions"
        assert email.text_body =~ "https://x/reset"
      end)
    end

    test "token warning email" do
      {:ok, _} = Oas.Tokens.TokenNotifier.deliver("m@example.com", "Test Acro notification", "Hi")

      assert_email_sent(
        to: [{"", "m@example.com"}],
        from: @from,
        subject: "Test Acro notification",
        text_body: "Hi"
      )
    end

    test "backup email carries the database as an attachment" do
      {:ok, _} = Oas.Repo.send_backup_email("backup@example.com", "test-acro.db", <<1, 2, 3>>)

      assert_email_sent(fn email ->
        assert email.to == [{"backup_recipient", "backup@example.com"}]
        assert email.from == @from
        assert email.subject == "Test Acro backup"
        assert email.text_body == "Backup database\n"

        assert [%Swoosh.Attachment{} = attachment] = email.attachments
        assert attachment.filename == "test-acro.db"
        assert attachment.content_type == "application/octet-stream"
        assert attachment.data == <<1, 2, 3>>
      end)
    end

    test "test email" do
      {:ok, _} = Oas.testEmail("someone@example.com")

      assert_email_sent(
        to: [{"", "someone@example.com"}],
        from: @from,
        subject: "Test Acro test",
        text_body: "Hello World\n"
      )
    end
  end

  describe "which mailer each email leaves through" do
    setup do
      mailer = Application.get_env(:oas, Oas.Mailer)
      token_mailer = Application.get_env(:oas, Oas.TokenMailer)

      Application.put_env(:oas, Oas.Mailer, adapter: TaggingAdapter, tag: :mailer)

      Application.put_env(:oas, Oas.TokenMailer,
        adapter: TaggingAdapter,
        tag: :token_mailer,
        from: @from
      )

      on_exit(fn ->
        Application.put_env(:oas, Oas.Mailer, mailer)
        Application.put_env(:oas, Oas.TokenMailer, token_mailer)
      end)
    end

    test "member, backup and test email use Oas.Mailer; token email uses Oas.TokenMailer" do
      member = Oas.MembersFixtures.member_fixture()

      Oas.Members.MemberNotifier.deliver_confirmation_instructions(member, "https://x/confirm")
      assert_received {:sent_via, :mailer, %{subject: "Confirmation instructions"}}

      Oas.Repo.send_backup_email("backup@example.com", "b.db", "data")
      assert_received {:sent_via, :mailer, %{subject: "Test Acro backup"}}

      Oas.testEmail("someone@example.com")
      assert_received {:sent_via, :mailer, %{subject: "Test Acro test"}}

      Oas.Tokens.TokenNotifier.deliver("m@example.com", "Test Acro notification", "Hi")
      assert_received {:sent_via, :token_mailer, %{subject: "Test Acro notification"}}
    end
  end
end
