defmodule OasWeb.Schema.SchemaTypes do
  use Absinthe.Schema.Notation

  object :success do
    field :success, :boolean
  end
end
