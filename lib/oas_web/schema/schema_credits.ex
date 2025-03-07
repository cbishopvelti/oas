import Ecto.Query, only: [from: 2]
defmodule OasWeb.Schema.SchemaCredits do
  use Absinthe.Schema.Notation

  object :credit do
    field :id, :integer
    field :what, :string
    field :when, :string
    field :expires_on, :string
    field :amount, :string
    field :after_amount, :string
    field :who_member_id, :integer
    field :transaction, :transaction
  end

  object :credits_queries do
    field :credits, list_of(:credit) do
      arg :member_id, :integer
      resolve fn _, %{member_id: member_id}, _ ->
        # result = from(c in Oas.Credits.Credit,
        #   preload: [:transaction, ],
        #   where: c.who_member_id == ^member_id, order_by: [desc: c.when, desc: c.id]
        # )
        # |> Oas.Repo.all()
        {credits, _} = Oas.Credits.Credit.get_credit_amount(%{member_id: member_id})

        {:ok, credits}
      end
    end
  end
end
