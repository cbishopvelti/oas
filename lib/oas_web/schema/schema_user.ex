import Ecto.Query, only: [from: 2, where: 3]
defmodule OasWeb.Schema.SchemaUser do
  use Absinthe.Schema.Notation

  object :user do
    field :name, :string
    field :logout_link, :string
  end

  object :user_queries do
    field :user, :user do
      resolve fn _, _, conn -> 
        %{context: context} = conn

        {:ok, %{
          name: Map.get(context, :current_member, %{}) |> Map.get(:name),
          logout_link: Map.get(context, :logout_link, %{})
        }}
      end
    end
  end
end
