  import Ecto.Query, only: [from: 2]
defmodule OasWeb.Schema.SchemaConfig do
  use Absinthe.Schema.Notation

  object :config_token do
    field :id, :integer
    field :value, :string
    field :quantity, :integer
  end

  object :config_config do
    field :id, :integer
    field :token_expiry_days, :integer
    field :temporary_trainings, :integer
    field :bacs, :string
    field :content, :string
    field :enable_booking, :boolean
    field :name, :string
    field :gocardless_id, :string
    field :gocardless_key, :string
    field :gocardless_account_id, :string
    field :credits, :boolean
    field :backup_recipient, :string
  end

  object :public_config_config do
    field :enable_booking, :boolean
    field :content, :string
    field :credits, :boolean
  end

  object :config_queries do
    field :config_token, :config_token do
      arg :token_quantity, non_null(:integer)
      resolve fn _, %{token_quantity: token_quantity}, _ ->
        result = from(ct in Oas.Config.Tokens, where: ct.quantity <= ^token_quantity, order_by: [desc: ct.quantity], limit: 1)
          |> Oas.Repo.one
        {:ok, result}
      end
    end
    field :config_tokens, list_of(:config_token) do
      resolve fn _, _, _ ->
        results = from(ct in Oas.Config.Tokens, select: ct, order_by: [asc: ct.quantity])
          |> Oas.Repo.all

        {:ok, results}
      end
    end
    field :config_config, :config_config do
      resolve fn _, _, _ ->
        result = from(cc in Oas.Config.Config, select: cc)
          |> Oas.Repo.one

        {:ok, result}
      end
    end
    field :public_config_config, :public_config_config do
      resolve fn _, _, _ ->
        result = from(cc in Oas.Config.Config, select: cc)
          |> Oas.Repo.one

        {:ok, result}
      end
    end
  end

  object :config_mutations do
    field :save_config_token, :config_token do
      arg :quantity, non_null(:integer)
      arg :value, non_null(:string)
      resolve fn _, args, _ ->
        %Oas.Config.Tokens{}
        |> Ecto.Changeset.cast(args, [:quantity, :value])
        |> Oas.Repo.insert
        |> OasWeb.Schema.SchemaUtils.handle_error
      end
    end
    field :delete_config_token, :success do
      arg :id, non_null(:integer)
      resolve fn _, %{id: id}, _ ->
        Oas.Repo.get!(Oas.Config.Tokens, id) |>
          Oas.Repo.delete!

        {:ok, %{success: true}}
      end
    end
    field :save_config_config, :config_config do
      arg :token_expiry_days, :integer
      arg :temporary_trainings, :integer
      arg :bacs, :string
      arg :content, :string
      arg :enable_booking, :boolean
      arg :name, :string
      arg :gocardless_id, :string
      arg :gocardless_key, :string
      arg :gocardless_account_id, :string
      arg :credits, :boolean
      arg :backup_recipient, :string
      resolve fn _, args, _ ->

        result = from(cc in Oas.Config.Config, select: cc)
        |> Oas.Repo.one
        |> Ecto.Changeset.cast(args, [
          :token_expiry_days, :temporary_trainings,
          :bacs, :enable_booking, :name,
          :gocardless_id, :gocardless_key, :gocardless_account_id,
          :credits, :content, :backup_recipient
        ], empty_values: [[], ""])
        |> Ecto.Changeset.validate_format(:backup_recipient, ~r/@/)
        |> Oas.Repo.update
        |> OasWeb.Schema.SchemaUtils.handle_error

        Oas.Gocardless.Supervisor.restart()

        result
      end
    end

    field :global_warnings_clear, list_of(:global_warning) do
      arg :key, non_null(:string)
      resolve fn _, %{key: key}, _ ->
        :ets.delete(:global_warnings, String.to_existing_atom(key))
        items = :ets.tab2list(:global_warnings)
        |> Enum.map(fn {key, warning} ->
          %{
            key: key,
            warning: warning
          }
        end)

        {:ok, items}
      end
    end
  end

  object :global_warning do
    field :key, :string
    field :warning, :string
  end

  object :config_subscriptions do
    field :global_warnings, list_of(:global_warning) do
      config fn _args, _ ->
        # Send any existing errors
        spawn(fn ->
          items = :ets.tab2list(:global_warnings)
          Absinthe.Subscription.publish(OasWeb.Endpoint, items |> Enum.map(fn {key, warning} ->
            %{
              key: key,
              warning: warning
            }
          end), [global_warnings: "*"])
        end)
        {:ok, topic: "*"}
      end
      trigger :global_warnings_clear, topic: fn _args ->
        "*"
      end
      resolve fn args, _, _ ->
        {:ok, args}
      end
    end
  end

  # OasWeb.Schema.SchemaConfig.test_warning_subscription()
  def test_warning_subscription do
    # Phoenix.PubSub.broadcast!(Oas.PubSub, "global_warnings", "global_warnings")
    # Absinthe.Subscription.publish(OasWeb.Endpoint, [%{key: "1", warning: "This is a warning"}], [global_warnings: "*"])
    Oas.Gocardless.send_warning(:gocardless_get_accounts, "gocardless error")
  end

  # OasWeb.Schema.SchemaConfig.test_delete_warning()
  def test_delete_warning do
    # DOESNT WORK, doesnt trigger the subscription for some reason
    # mutation = """
    # mutation ($key: String!) {
    #   global_warnings_clear(key: $key) {
    #     key,
    #     warning
    #   }
    # }
    # """
    # Absinthe.run(mutation, OasWeb.Schema, variables: %{"key" => "gocardless_get_accounts"}, context: %{
    #   current_member: %{
    #     is_admin: true,
    #     is_active: true
    #   }
    # })
    Oas.Gocardless.delete_warning(:gocardless_get_accounts)
  end
end
