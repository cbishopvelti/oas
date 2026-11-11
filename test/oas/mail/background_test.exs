defmodule Oas.Mail.BackgroundTest do
  # Uses the shared :global_warnings table, so not async.
  use Oas.DataCase, async: false

  alias Oas.Mail.Background

  setup do
    :ets.delete(:global_warnings, Background.warning_key())
    on_exit(fn -> :ets.delete(:global_warnings, Background.warning_key()) end)
    :ok
  end

  defp warning() do
    case :ets.lookup(:global_warnings, Background.warning_key()) do
      [{_, warning}] -> warning
      [] -> nil
    end
  end

  defp await(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 1_000
  end

  test "sends the email from a task the test can still see" do
    {:ok, pid} =
      Background.run(fn ->
        Oas.Mail.deliver("member@example.com", "Notification", "Hi",
          mailer: Oas.TokenMailer
        )
      end)

    assert pid != self()
    assert_receive {:email, %Swoosh.Email{subject: "Notification", to: [{"", "member@example.com"}]}}, 1_000
    await(pid)
    assert warning() == nil
  end

  test "a failed send raises an admin warning and the next success clears it" do
    {:ok, pid} =
      Background.run(fn -> {:error, :smtp_down} end,
        description: "Warning email to member@example.com"
      )

    await(pid)
    assert warning() =~ "Warning email to member@example.com failed to send"
    assert warning() =~ ":smtp_down"

    {:ok, pid} = Background.run(fn -> nil end)
    await(pid)
    assert warning() == nil
  end

  test "an exception in the task is caught and reported, not raised in the caller" do
    {:ok, pid} = Background.run(fn -> raise "connection refused" end)

    await(pid)
    assert warning() =~ "connection refused"
  end

  test "waits for the delay before sending" do
    {:ok, pid} =
      Background.run(
        fn -> Oas.Mail.deliver("member@example.com", "Later", "Hi", mailer: Oas.TokenMailer) end,
        delay: 100
      )

    refute_received {:email, _}
    assert_receive {:email, %Swoosh.Email{subject: "Later"}}, 1_000
    await(pid)
  end
end
