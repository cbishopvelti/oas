defmodule Oas.SettingsTest do
  use Oas.DataCase

  alias Oas.Settings

  describe "config" do
    test "reads the settings row and single values" do
      config = Settings.get_config()
      assert %Oas.Config.Config{} = config
      assert Settings.get_config!().id == config.id
      assert Settings.get_config_value(:token_expiry_days) == config.token_expiry_days
    end

    test "update_config only changes the listed fields" do
      before = Settings.get_config()

      assert {:ok, updated} =
               Settings.update_config(%{name: "New name", bacs: "ignored"}, [:name])

      assert updated.name == "New name"
      assert updated.bacs == before.bacs
      assert Settings.get_config().name == "New name"
    end

    test "update_config rejects a backup recipient without an @" do
      assert {:error, changeset} =
               Settings.update_config(%{backup_recipient: "nope"}, [:backup_recipient])

      assert %{backup_recipient: [_]} = errors_on(changeset)
    end

    test "update_config passes empty_values to cast" do
      {:ok, _} = Settings.update_config(%{name: "Kept"}, [:name])
      {:ok, updated} = Settings.update_config(%{name: ""}, [:name], empty_values: [[], ""])
      assert updated.name == nil
    end
  end

  describe "society fields" do
    test "the existing row gets the Oxfordshire defaults" do
      config = Settings.get_config()
      assert config.time_zone == "Europe/London"
      assert config.currency == "GBP"
      assert config.phone_country_code == "44"
      assert config.short_name == nil
      assert config.logo_url == nil
    end

    @fields [
      :short_name,
      :contact_email,
      :time_zone,
      :currency,
      :phone_country_code,
      :logo_url,
      :primary_color,
      :public_site_title
    ]

    test "valid values are saved" do
      attrs = %{
        short_name: "NYAS",
        contact_email: "hello@example.org",
        time_zone: "America/New_York",
        currency: "USD",
        phone_country_code: "1",
        logo_url: "https://example.org/logo.png",
        primary_color: "#1A2b3c",
        public_site_title: "New York Acro"
      }

      assert {:ok, updated} = Settings.update_config(attrs, @fields)
      assert Map.take(updated, @fields) == attrs
      assert Map.take(Settings.get_config(), @fields) == attrs
      assert {:ok, _} = Settings.update_config(%{primary_color: "#abc"}, [:primary_color])
    end

    test "invalid values are rejected" do
      attrs = %{
        contact_email: "nope",
        time_zone: "Europe/Atlantis",
        currency: "gbp",
        phone_country_code: "+44",
        primary_color: "red"
      }

      assert {:error, changeset} = Settings.update_config(attrs, @fields)

      assert %{
               contact_email: [_],
               time_zone: [_],
               currency: [_],
               phone_country_code: [_],
               primary_color: [_]
             } = errors_on(changeset)

      assert Settings.get_config().time_zone == "Europe/London"
    end

    test "time zone, currency and phone code cannot be blanked" do
      assert {:error, changeset} =
               Settings.update_config(
                 %{time_zone: "", currency: "", phone_country_code: ""},
                 @fields
               )

      assert %{time_zone: [_], currency: [_], phone_country_code: [_]} = errors_on(changeset)
    end

    test "valid_time_zone?/1" do
      assert Settings.valid_time_zone?("Australia/Sydney")
      refute Settings.valid_time_zone?("Not/AZone")
      refute Settings.valid_time_zone?(nil)
    end
  end

  describe "llm" do
    test "reads and updates the LLM settings row" do
      assert %Oas.Config.ConfigLlm{} = Settings.get_llm()

      assert {:ok, updated} =
               Settings.update_llm(%{context: "Be nice", chat_enabled: true}, [
                 :context,
                 :chat_enabled
               ])

      assert updated.context == "Be nice"
      assert Settings.get_llm!().chat_enabled == true
    end
  end

  describe "tokens" do
    test "create, list, look up and delete token prices" do
      Enum.each(Settings.list_tokens(), &Settings.delete_token!(&1.id))

      {:ok, one} = Settings.create_token(%{quantity: 1, value: "5.00"})
      {:ok, ten} = Settings.create_token(%{quantity: 10, value: "4.50"})

      assert Enum.map(Settings.list_tokens(), & &1.id) == [one.id, ten.id]
      assert Enum.map(Settings.list_tokens(desc: :value), & &1.id) == [one.id, ten.id]
      assert Enum.map(Settings.list_tokens(desc: :quantity), & &1.id) == [ten.id, one.id]

      assert Settings.get_token_for_quantity(5).id == one.id
      assert Settings.get_token_for_quantity(10).id == ten.id
      assert Settings.get_token_for_quantity(0) == nil

      assert Settings.get_min_token!().id == ten.id
      assert Decimal.eq?(Settings.min_token_value(), "4.50")
      assert Decimal.eq?(Settings.max_token_value(), "5.00")

      Settings.delete_token!(one.id)
      assert Enum.map(Settings.list_tokens(), & &1.id) == [ten.id]
    end
  end
end
