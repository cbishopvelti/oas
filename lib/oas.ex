defmodule Oas do
  @moduledoc """
  Oas keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """


  def setAdmin do

    toSave = %Oas.Members.Member{
      password: "test2",
      email: "test2@test.com",
      is_admin: true,
      hashed_password: "test2"
    }

    Oas.Repo.insert(toSave)
  end

  # Oas.testEmail("someone@example.com")
  def testEmail(recipient) do
    email = Swoosh.Email.new()
    |> Swoosh.Email.to(recipient)
    |> Swoosh.Email.from(Application.get_env(:oas, Oas.TokenMailer)[:from])
    |> Swoosh.Email.subject("#{Oas.Settings.society_name()} test")
    # |> Swoosh.Email.html_body("<h1>Hello World</h1>")
    |> Swoosh.Email.text_body("Hello World\n")

    Oas.Mailer.deliver(email)
  end

end
