defmodule Oas.Mail.Background do
  @moduledoc """
  Sends an email outside the request that triggered it.

  Used for member warning emails (low credits/tokens, booked in by someone
  else) so a slow or failing mail server cannot delay or fail a booking or
  attendance request. Password reset, confirmation and update-email mails
  stay synchronous and do not use this.

  `run/2` starts `fun` under `Oas.TaskSupervisor` and returns the task's
  `{:ok, pid}`. `fun` should return what `Oas.Mail.deliver/4` returns, or
  anything other than `{:error, _}` when there was nothing to send.

  When `fun` returns `{:error, reason}`, raises or exits, the failure is
  logged and an admin global warning is raised under `#{inspect(:mail_failed)}`.
  The next successful background send clears it.

  Options:

    * `:delay` - milliseconds to wait before running `fun`. Defaults to 0.
    * `:description` - what is being sent, used in the log and the warning.

  In tests, Swoosh's test adapter delivers to the test process as well (the
  task carries it in `$callers`), so `assert_receive {:email, _}` or
  `Swoosh.TestAssertions.assert_email_sent/1` with a timeout still work.
  """

  require Logger

  @warning_key :mail_failed

  def warning_key, do: @warning_key

  def run(fun, opts \\ []) when is_function(fun, 0) do
    delay = Keyword.get(opts, :delay, 0)
    description = Keyword.get(opts, :description, "Email")

    Task.Supervisor.start_child(Oas.TaskSupervisor, fn ->
      if delay > 0, do: Process.sleep(delay)
      execute(fun, description)
    end)
  end

  @doc false
  # Runs `fun` in the calling process and records the outcome. Public so it
  # can be tested without a task.
  def execute(fun, description) do
    result =
      try do
        fun.()
      rescue
        e -> {:error, Exception.message(e)}
      catch
        kind, reason -> {:error, "#{kind}: #{inspect(reason)}"}
      end

    case result do
      {:error, reason} ->
        failed(description, reason)
        {:error, reason}

      other ->
        succeeded()
        other
    end
  end

  defp failed(description, reason) do
    reason = format_reason(reason)
    Logger.error("#{description} failed to send: #{reason}")

    at =
      try do
        Oas.Settings.now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S")
      rescue
        _ -> DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S")
      end

    Oas.Gocardless.send_warning(
      @warning_key,
      "#{description} failed to send on #{at}: #{reason}. Check the mail settings."
    )
  end

  defp succeeded() do
    case :ets.lookup(:global_warnings, @warning_key) do
      [] -> :ok
      _ -> Oas.Gocardless.delete_warning(@warning_key)
    end
  end

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)
end
