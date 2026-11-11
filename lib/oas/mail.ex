defmodule Oas.Mail do
  @moduledoc """
  The one place that builds and sends email.

  Every email uses the sender from the `Oas.TokenMailer` `:from` config
  (set by MAIL_FROM_ADDRESS / MAIL_FROM_NAME in runtime.exs).

  Options:

    * `:mailer` - the Swoosh mailer to send through. Defaults to `Oas.Mailer`.
      Token mail goes through `Oas.TokenMailer`, which has its own config.
    * `:attachments` - a list of attachments, each anything that
      `Swoosh.Email.attachment/2` accepts (a path or a `Swoosh.Attachment`).

  Returns `{:ok, email}` when the mailer accepts it, otherwise the mailer's
  error.
  """

  import Swoosh.Email

  def deliver(recipient, subject, body, opts \\ []) do
    mailer = Keyword.get(opts, :mailer, Oas.Mailer)

    email =
      new()
      |> to(recipient)
      |> from(from())
      |> subject(subject)
      |> text_body(body)

    email =
      opts
      |> Keyword.get(:attachments, [])
      |> Enum.reduce(email, &attachment(&2, &1))

    with {:ok, _metadata} <- mailer.deliver(email) do
      {:ok, email}
    end
  end

  defp from(), do: Application.get_env(:oas, Oas.TokenMailer)[:from]
end
