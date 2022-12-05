# filename: myapp/schema.ex
import Ecto.Query, only: [from: 2, where: 3]

defmodule OasWeb.Schema do
  use Absinthe.Schema

  import_types Absinthe.Plug.Types
  import_types OasWeb.Schema.SchemaTypes
  import_types OasWeb.Schema.SchemaAttendance
  import_types OasWeb.Schema.SchemaTraining
  import_types OasWeb.Schema.SchemaTransaction
  import_types OasWeb.Schema.SchemaTransactionsImport
  import_types OasWeb.Schema.SchemaMember
  import_types OasWeb.Schema.SchemaMembershipPeriod
  import_types OasWeb.Schema.SchemaToken
  import_types OasWeb.Schema.SchemaAnalysis
  import_types OasWeb.Schema.SchemaUser
  import_types OasWeb.Schema.SchemaConfig

  query do
    import_fields :attendance_queries

    import_fields :member_queries
    import_fields :membership_period_queries

    import_fields :transaction_queries
    import_fields :transactions_import_queries

    import_fields :token_queries

    import_fields :training_queries

    import_fields :analysis_queries
    
    import_fields :user_queries

    import_fields :config_queries
  end


  mutation do 
    import_fields :member_mutations
    import_fields :membership_period_mutations

    import_fields :transaction_mutations
    import_fields :transactions_import_mutations

    import_fields :token_mutations

    import_fields :training_mutations

    import_fields :attendance_mutations

    import_fields :config_mutations
  end
  

  # Public resolver
  def myMiddleware(middleware, %Absinthe.Type.Field{identifier: :public_register}, %Absinthe.Type.Object{identifier: :mutation}) do
    middleware
  end
  def myMiddleware(middleware, %Absinthe.Type.Field{identifier: :public_tokens}, %Absinthe.Type.Object{identifier: :query}) do
    middleware
  end
  def myMiddleware(middleware, %Absinthe.Type.Field{identifier: :public_bacs}, %Absinthe.Type.Object{identifier: :query}) do
    middleware
  end
  def myMiddleware(middleware, %Absinthe.Type.Field{identifier: :public_outstanding_attendance}, %Absinthe.Type.Object{identifier: :query}) do
    middleware
  end
  # isAdmin and isReviewer can read data
  def myMiddleware(middleware, field, %Absinthe.Type.Object{identifier: identifier}) when identifier in [:query, :subscription] do
    [OasWeb.Schema.MiddlewareQuery | middleware]
  end
  # isAdmin can mutate data
  def myMiddleware(middleware, field, %Absinthe.Type.Object{identifier: identifier}) when identifier in [:mutation] do
    [OasWeb.Schema.MiddlewareMutation | middleware]
  end
  # for :option
  def myMiddleware(middleware, _field, _object) do
    middleware
  end

  def middleware(middleware, field, object) do
    middleware
    |> myMiddleware(field, object)
  end
  
end