defmodule Oas.Credits.CreditsCredits do
  use Ecto.Schema

  schema "credits_credits" do
    field :amount, :decimal
    belongs_to :uses, Oas.Credits.Credit
    belongs_to :used_for, Oas.Credits.Credit
  end



end
