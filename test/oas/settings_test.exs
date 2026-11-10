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

  describe "llm" do
    test "reads and updates the LLM settings row" do
      assert %Oas.Config.ConfigLlm{} = Settings.get_llm()

      assert {:ok, updated} =
               Settings.update_llm(%{context: "Be nice", chat_enabled: true}, [:context, :chat_enabled])

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
