defmodule Oas.Tokens.TokenNotifier do
  import Swoosh.Email

  alias Oas.TokenMailer

  def deliver(recipient, subject, body) do
    from = Application.get_env(:oas, Oas.TokenMailer)[:from]
    email =
      new()
      |> to(recipient)
      |> from(from)
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- TokenMailer.deliver(email) do
      {:ok, email}
    end
  end
end
