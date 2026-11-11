defmodule OasWeb.FreshDatabaseTest do
  # Boots the app on a brand new database and checks the first pages a
  # visitor sees do not crash. It only means something against a database
  # that the migrations have just created, so it is excluded from `mix test`.
  # Run it with `mix test.fresh_db`, which makes a new empty SQLite file, runs
  # every migration on it and then runs this file.
  use OasWeb.ConnCase

  @moduletag :fresh_db

  @public_query """
  query {
    public_config_config {
      name short_name logo_url primary_color public_site_title
      currency time_zone content credits enable_booking
    }
    public_config_tokens {
      token_expiry_days
      tokens { quantity value }
    }
  }
  """

  setup do
    assert Oas.Repo.aggregate(Oas.Members.Member, :count) == 0,
           "this test needs a new database: run it with `mix test.fresh_db`"

    :ok
  end

  test "the settings rows exist" do
    config = Oas.Settings.get_config!()
    assert config.name == "Society"
    assert config.token_expiry_days == 365
    assert Oas.Settings.get_llm!()
    assert Oas.Settings.list_tokens() != []
  end

  test "the home page GraphQL queries answer", %{conn: conn} do
    conn = post(conn, "/api/graphql", %{"query" => @public_query})
    body = json_response(conn, 200)

    refute Map.has_key?(body, "errors"), inspect(body["errors"])
    assert body["data"]["public_config_config"]["name"] == "Society"
    assert body["data"]["public_config_config"]["currency"] == "GBP"
    assert body["data"]["public_config_tokens"]["token_expiry_days"] == 365
  end

  test "the auth server home and log in pages render", %{conn: conn} do
    assert html_response(get(conn, "/"), 200) =~ "Society"
    assert html_response(get(build_conn(), "/members/log_in"), 200) =~ "Log in"
  end
end
