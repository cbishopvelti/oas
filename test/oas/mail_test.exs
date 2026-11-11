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

  @token_mailer_from Application.compile_env(:oas, Oas.TokenMailer)[:from]
  @address elem(@token_mailer_from, 1)
  @from {"Test Acro", @address}

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
        from: @token_mailer_from
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

  describe "sender" do
    setup do
      on_exit(fn -> Application.delete_env(:oas, :mail_from_name) end)
    end

    test "From name is the society name and follows changes to it" do
      Oas.testEmail("a@example.com")
      assert_email_sent(from: {"Test Acro", @address})

      {:ok, _} = Oas.Settings.update_config(%{name: "Other Club"}, [:name])
      Oas.testEmail("a@example.com")
      assert_email_sent(from: {"Other Club", @address})
    end

    test "From name falls back to OAS when the society name is blank" do
      {:ok, _} = Oas.Settings.update_config(%{name: "  "}, [:name], empty_values: [])
      Oas.testEmail("a@example.com")
      assert_email_sent(from: {"OAS", @address})
    end

    test "MAIL_FROM_NAME (:mail_from_name) wins over the society name" do
      Application.put_env(:oas, :mail_from_name, "Env Sender")
      Oas.testEmail("a@example.com")
      assert_email_sent(from: {"Env Sender", @address})
    end

    test "a plain address in the :from config still works" do
      token_mailer = Application.get_env(:oas, Oas.TokenMailer)

      Application.put_env(
        :oas,
        Oas.TokenMailer,
        Keyword.put(token_mailer, :from, "plain@example.com")
      )

      on_exit(fn -> Application.put_env(:oas, Oas.TokenMailer, token_mailer) end)

      assert Oas.Mail.sender() == {"Test Acro", "plain@example.com"}
    end

    test "Reply-To is the contact email when set" do
      {:ok, _} =
        Oas.Settings.update_config(%{contact_email: "hello@example.com"}, [:contact_email])

      Oas.testEmail("a@example.com")

      assert_email_sent(fn email ->
        assert email.reply_to == {"", "hello@example.com"}
      end)
    end

    test "no Reply-To when the contact email is not set" do
      {:ok, _} = Oas.Settings.update_config(%{contact_email: nil}, [:contact_email])
      Oas.testEmail("a@example.com")

      assert_email_sent(fn email ->
        assert email.reply_to == nil
      end)
    end
  end
end
