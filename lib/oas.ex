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

  def testEmail do
    email = Swoosh.Email.new()
    |> Swoosh.Email.to({"chris", "chrisjbishop155@hotmail.com"})
    |> Swoosh.Email.from({"chris", "chris@oxfordshireacrosociety.co.uk"})
    |> Swoosh.Email.subject("Hello, Avengers!")
    # |> Swoosh.Email.html_body("<h1>Hello World</h1>")
    |> Swoosh.Email.text_body("Hello World\n")

    Oas.Mailer.deliver(email)
  end

end
