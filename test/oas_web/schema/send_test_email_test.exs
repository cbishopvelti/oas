defmodule OasWeb.Schema.SendTestEmailTest do
  # Not async: the failure test swaps the mailer config for the whole app.
  use Oas.DataCase, async: false

  import Swoosh.TestAssertions

  @admin %{current_member: %{is_admin: true, is_reviewer: false, is_active: true}}
  @reviewer %{current_member: %{is_admin: false, is_reviewer: true, is_active: true}}

  @send """
  mutation ($to: String!) {
    send_test_email(to: $to) { success error }
  }
  """

  defmodule FailingAdapter do
    use Swoosh.Adapter

    @impl true
    def deliver(_email, _config), do: {:error, "relay refused"}
  end

  setup do
    {:ok, _} = Oas.Settings.update_config(%{name: "Test Acro"}, [:name])
    :ok
  end

  test "admin can send a test email" do
    assert {:ok, %{data: %{"send_test_email" => %{"success" => true, "error" => nil}}}} =
             Absinthe.run(@send, OasWeb.Schema, variables: %{"to" => " admin@example.com "}, context: @admin)

    assert_email_sent(fn email ->
      assert email.to == [{"", "admin@example.com"}]
      assert email.subject == "Test Acro test"
    end)
  end

  test "a failed send returns the error text" do
    mailer = Application.get_env(:oas, Oas.Mailer)
    Application.put_env(:oas, Oas.Mailer, adapter: FailingAdapter)
    on_exit(fn -> Application.put_env(:oas, Oas.Mailer, mailer) end)

    assert {:ok, %{data: %{"send_test_email" => %{"success" => false, "error" => "relay refused"}}}} =
             Absinthe.run(@send, OasWeb.Schema, variables: %{"to" => "admin@example.com"}, context: @admin)
  end

  test "a blank address is refused without sending" do
    assert {:ok, %{data: %{"send_test_email" => %{"success" => false, "error" => error}}}} =
             Absinthe.run(@send, OasWeb.Schema, variables: %{"to" => "  "}, context: @admin)

    assert error =~ "email address"
    assert_no_email_sent()
  end

  test "non-admins cannot send" do
    assert {:ok, %{errors: [_ | _]}} =
             Absinthe.run(@send, OasWeb.Schema, variables: %{"to" => "admin@example.com"}, context: @reviewer)

    assert_no_email_sent()
  end
end
