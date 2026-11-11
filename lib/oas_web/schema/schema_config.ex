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
    field :membership_terms, :string
    field :enable_booking, :boolean
    field :name, :string
    field :gocardless_enabled, :boolean
    field :gocardless_id, :string
    field :gocardless_key, :string
    field :gocardless_account_id, :string
    field :credits, :boolean
    field :backup_recipient, :string
    field :short_name, :string
    field :contact_email, :string
    field :time_zone, :string
    field :currency, :string
    field :phone_country_code, :string
    field :logo_url, :string
    field :primary_color, :string
    field :public_site_title, :string
  end

  object :send_test_email_result do
    field :success, :boolean
    field :error, :string
  end

  object :config_llm do
    field :chat_enabled, :boolean
    field :llm_enabled, :boolean
    field :context, :string
  end

  # Public (unauthenticated) view of the settings row. contact_email and
  # phone_country_code stay admin-only.
  object :public_config_config do
    field :enable_booking, :boolean
    field :content, :string
    field :membership_terms, :string
    field :credits, :boolean
    field :name, :string
    field :short_name, :string
    field :time_zone, :string
    field :currency, :string
    field :logo_url, :string
    field :primary_color, :string
    field :public_site_title, :string
  end

  object :public_config_llm do
    field :chat_enabled, :boolean
    field :llm_enabled, :boolean
  end

  object :config_queries do
    field :global_warnings, list_of(:global_warning) do
      resolve fn _, _, _ ->
        {:ok, Oas.Gocardless.list_warnings()}
      end
    end
    field :config_token, :config_token do
      arg :token_quantity, non_null(:integer)
      resolve fn _, %{token_quantity: token_quantity}, _ ->
        result = Oas.Settings.get_token_for_quantity(token_quantity)
        {:ok, result}
      end
    end
    field :config_tokens, list_of(:config_token) do
      resolve fn _, _, _ ->
        results = Oas.Settings.list_tokens()

        {:ok, results}
      end
    end
    field :config_config, :config_config do
      resolve fn _, _, _ ->
        result = Oas.Settings.get_config()

        {:ok, result}
      end
    end
    field :public_config_config, :public_config_config do
      resolve fn _, _, _ ->
        result = Oas.Settings.get_config()

        {:ok, result}
      end
    end
    field :public_config_llm, :public_config_llm do
      resolve fn _, _, _ ->
        result = Oas.Settings.get_llm()

        {:ok, result}
      end
    end
    field :config_llm, :config_llm do
      resolve fn _, _, _ ->
        result = Oas.Settings.get_llm()
        {:ok, result}
      end
    end
  end

  object :config_mutations do
    field :save_config_token, :config_token do
      arg :quantity, non_null(:integer)
      arg :value, non_null(:string)
      resolve fn _, args, _ ->
        Oas.Settings.create_token(args)
        |> OasWeb.Schema.SchemaUtils.handle_error
      end
    end
    field :delete_config_token, :success do
      arg :id, non_null(:integer)
      resolve fn _, %{id: id}, _ ->
        Oas.Settings.delete_token!(id)

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
      # arg :gocardless_id, :string
      # arg :gocardless_key, :string
      # arg :gocardless_account_id, :string
      arg :credits, :boolean
      arg :backup_recipient, :string
      arg :short_name, :string
      arg :contact_email, :string
      arg :time_zone, :string
      arg :currency, :string
      arg :phone_country_code, :string
      arg :logo_url, :string
      arg :primary_color, :string
      arg :public_site_title, :string
      resolve fn _, args, _ ->

        result = Oas.Settings.update_config(args, [
          :token_expiry_days, :temporary_trainings,
          :enable_booking, :name,
          # :gocardless_id, :gocardless_key, :gocardless_account_id,
          :credits, :backup_recipient,
          :short_name, :contact_email, :time_zone, :currency,
          :phone_country_code, :logo_url, :primary_color, :public_site_title
        ], empty_values: [[], ""])
        |> OasWeb.Schema.SchemaUtils.handle_error

        result
      end
    end
    field :save_config_content, :config_config do
      arg :bacs, non_null(:string)
      arg :content, non_null(:string)
      arg :membership_terms, :string
      resolve fn _, args, _ ->
        result = Oas.Settings.update_config(args, [
          :bacs, :content, :membership_terms
        ], empty_values: [[], ""])
        |> OasWeb.Schema.SchemaUtils.handle_error

        result
      end
    end
    field :save_config_gocardless, :config_config do
      arg :gocardless_enabled, :boolean
      arg :gocardless_id, :string
      arg :gocardless_key, :string
      arg :gocardless_account_id, :string
      resolve fn _, args, _ ->
        result = Oas.Settings.update_config(args, [
          :gocardless_enabled, :gocardless_id, :gocardless_key, :gocardless_account_id
        ], empty_values: [[], ""])
        |> OasWeb.Schema.SchemaUtils.handle_error

        Oas.Gocardless.Supervisor.restart()

        result
      end
    end

    # Sends the same email as Oas.testEmail/1, so an admin can check the mail
    # settings work. A failed send comes back as success: false with the
    # mailer's error text rather than as a GraphQL error.
    field :send_test_email, :send_test_email_result do
      arg :to, non_null(:string)
      resolve fn _, %{to: to}, _ ->
        {:ok, send_test_email(String.trim(to))}
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
    field :save_config_llm, :config_llm do
      arg :chat_enabled, non_null(:boolean)
      arg :llm_enabled, non_null(:boolean)
      arg :context, non_null(:string)
      resolve fn _, %{context: context, chat_enabled: chat_enabled, llm_enabled: llm_enabled}, _ ->
        result = Oas.Settings.update_llm(%{
          context: context,
          chat_enabled: chat_enabled,
          llm_enabled: llm_enabled
        }, [:context, :chat_enabled, :llm_enabled], empty_values: [])
        |> OasWeb.Schema.SchemaUtils.handle_error()

        result
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
        # Existing warnings are fetched by the client via the global_warnings
        # query; publishing from here raced the subscription registration.
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

  def send_test_email(""), do: %{success: false, error: "Enter an email address"}

  def send_test_email(to) do
    case Oas.testEmail(to) do
      {:ok, _email} -> %{success: true, error: nil}
      {:error, reason} -> %{success: false, error: error_text(reason)}
      other -> %{success: false, error: error_text(other)}
    end
  rescue
    e -> %{success: false, error: Exception.message(e)}
  end

  defp error_text(reason) when is_binary(reason), do: reason
  defp error_text(%{__exception__: true} = e), do: Exception.message(e)
  defp error_text(reason), do: inspect(reason)
end
