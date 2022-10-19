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

end
