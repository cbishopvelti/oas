defmodule OasWeb.Schema.ConfigConfigTest do
  use Oas.DataCase

  @admin %{current_member: %{is_admin: true, is_reviewer: false, is_active: true}}

  @save """
  mutation ($short_name: String, $time_zone: String, $currency: String,
            $contact_email: String, $phone_country_code: String,
            $logo_url: String, $primary_color: String, $public_site_title: String) {
    save_config_config(short_name: $short_name, time_zone: $time_zone, currency: $currency,
                       contact_email: $contact_email, phone_country_code: $phone_country_code,
                       logo_url: $logo_url, primary_color: $primary_color,
                       public_site_title: $public_site_title) {
      short_name time_zone currency contact_email phone_country_code
      logo_url primary_color public_site_title
    }
  }
  """

  test "admin can save and read the society fields" do
    vars = %{
      "short_name" => "OAS",
      "time_zone" => "America/New_York",
      "currency" => "USD",
      "contact_email" => "hello@example.com",
      "phone_country_code" => "1",
      "logo_url" => "https://example.com/logo.png",
      "primary_color" => "#1a2b3c",
      "public_site_title" => "Acro Society"
    }

    assert {:ok, %{data: %{"save_config_config" => saved}}} =
             Absinthe.run(@save, OasWeb.Schema, variables: vars, context: @admin)

    assert saved == vars

    assert {:ok, %{data: %{"config_config" => read}}} =
             Absinthe.run("{ config_config { time_zone currency contact_email } }", OasWeb.Schema,
               context: @admin
             )

    assert read == %{"time_zone" => "America/New_York", "currency" => "USD", "contact_email" => "hello@example.com"}
  end

  test "invalid society fields come back as errors" do
    assert {:ok, %{errors: errors}} =
             Absinthe.run(@save, OasWeb.Schema,
               variables: %{"time_zone" => "Mars/Base", "currency" => "pounds"},
               context: @admin
             )

    assert errors != []
    assert Oas.Settings.get_config().time_zone == "Europe/London"
  end

  test "public config exposes society branding but not contact details" do
    Oas.Settings.update_config(%{short_name: "OAS", currency: "EUR"}, [:short_name, :currency])

    assert {:ok, %{data: %{"public_config_config" => public}}} =
             Absinthe.run(
               "{ public_config_config { name short_name time_zone currency logo_url primary_color public_site_title } }",
               OasWeb.Schema,
               context: %{}
             )

    assert public["short_name"] == "OAS"
    assert public["currency"] == "EUR"
    assert public["time_zone"] == "Europe/London"

    assert {:ok, %{errors: [_ | _]}} =
             Absinthe.run("{ public_config_config { contact_email } }", OasWeb.Schema, context: %{})

    assert {:ok, %{errors: [_ | _]}} =
             Absinthe.run("{ public_config_config { phone_country_code } }", OasWeb.Schema, context: %{})
  end

  @save_content """
  mutation ($content: String!, $bacs: String!, $membership_terms: String) {
    save_config_content(content: $content, bacs: $bacs, membership_terms: $membership_terms) {
      membership_terms
    }
  }
  """

  test "admin can save membership terms, the public form can read them, and empty clears them" do
    vars = %{"content" => "<p>Hi</p>", "bacs" => "00-00-00", "membership_terms" => "<p>Be careful</p>"}

    assert {:ok, %{data: %{"save_config_content" => %{"membership_terms" => "<p>Be careful</p>"}}}} =
             Absinthe.run(@save_content, OasWeb.Schema, variables: vars, context: @admin)

    assert {:ok, %{data: %{"public_config_config" => %{"membership_terms" => "<p>Be careful</p>"}}}} =
             Absinthe.run("{ public_config_config { membership_terms } }", OasWeb.Schema, context: %{})

    assert {:ok, %{data: %{"save_config_content" => %{"membership_terms" => nil}}}} =
             Absinthe.run(@save_content, OasWeb.Schema,
               variables: Map.put(vars, "membership_terms", ""),
               context: @admin
             )
  end
end
