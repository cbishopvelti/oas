defmodule Oas.Tokens.TokenNotifier do
  # Token and booking warnings go through Oas.TokenMailer, which prod
  # configures separately from Oas.Mailer.
  def deliver(recipient, subject, body) do
    Oas.Mail.deliver(recipient, subject, body, mailer: Oas.TokenMailer)
  end
end
