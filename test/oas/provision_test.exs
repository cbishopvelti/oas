defmodule Oas.ProvisionTest do
  use Oas.DataCase

  alias Oas.Provision

  @opts %{
    name: "Bristol Acro",
    time_zone: "Europe/Paris",
    currency: "EUR",
    admin_email: "first.admin@example.com",
    admin_name: "First Admin"
  }

  defp token_from(link) do
    link |> URI.parse() |> Map.fetch!(:path) |> String.split("/") |> List.last()
  end

  test "sets the settings, creates the admin and gives a working set-password link" do
    assert {:ok, report} = Provision.run(@opts)

    config = Oas.Settings.get_config!()

    assert {config.name, config.time_zone, config.currency} ==
             {"Bristol Acro", "Europe/Paris", "EUR"}

    assert report.admin == :created
    member = Oas.Members.get_member_by_email("first.admin@example.com")
    assert member.is_admin and member.is_active
    assert member.name == "First Admin"

    assert report.link =~ "/members/reset_password/"
    assert Oas.Members.get_member_by_reset_password_token(token_from(report.link)).id == member.id
    refute Provision.unchanged?(report)
  end

  test "a second run changes nothing" do
    {:ok, _} = Provision.run(@opts)
    tokens = Repo.aggregate(Oas.Members.MemberToken, :count)
    members = Repo.aggregate(Oas.Members.Member, :count)

    assert {:ok, report} = Provision.run(@opts)
    assert report.settings == []
    assert report.admin == :exists
    assert report.link == nil
    assert Provision.unchanged?(report)
    assert Repo.aggregate(Oas.Members.MemberToken, :count) == tokens
    assert Repo.aggregate(Oas.Members.Member, :count) == members
  end

  test "new_link gives an existing admin a fresh link" do
    {:ok, _} = Provision.run(@opts)
    assert {:ok, %{admin: :exists, link: link}} = Provision.run(Map.put(@opts, :new_link, true))
    assert Oas.Members.get_member_by_reset_password_token(token_from(link))
  end

  test "an invalid setting saves nothing" do
    before = Oas.Settings.get_config!()

    assert {:error, :settings, changeset} = Provision.run(%{@opts | time_zone: "Mars/Olympus"})
    assert {"is not a known time zone", _} = changeset.errors[:time_zone]

    assert Oas.Settings.get_config!().name == before.name
    assert Oas.Members.get_member_by_email("first.admin@example.com") == nil
  end

  test "an invalid admin email rolls back the settings" do
    before = Oas.Settings.get_config!()
    assert {:error, :admin, _} = Provision.run(%{@opts | admin_email: "not an email"})
    assert Oas.Settings.get_config!().name == before.name
  end

  test "an existing member who is not an admin is left alone" do
    {:ok, member} =
      Repo.insert(%Oas.Members.Member{
        name: "Someone",
        email: "first.admin@example.com",
        hashed_password: "x",
        is_admin: false
      })

    assert {:ok, %{admin: :exists_not_admin, link: nil}} =
             Provision.run(Map.put(@opts, :new_link, true))

    refute Repo.reload!(member).is_admin
  end

  describe "mix oas.provision options" do
    test "need all five values" do
      assert_raise Mix.Error, ~r/Missing: --currency, --admin-name/, fn ->
        Mix.Tasks.Oas.Provision.parse!(~w(--name X --time-zone Europe/London --admin-email a@b.c))
      end
    end

    test "do not take a password" do
      assert_raise Mix.Error, ~r/password/, fn ->
        Mix.Tasks.Oas.Provision.parse!(~w(--password secret))
      end
    end

    test "parse" do
      assert Mix.Tasks.Oas.Provision.parse!(
               ~w(--name X --time-zone Europe/London --currency GBP --admin-email a@b.c --admin-name Y --new-link)
             ) == %{
               name: "X",
               time_zone: "Europe/London",
               currency: "GBP",
               admin_email: "a@b.c",
               admin_name: "Y",
               new_link: true
             }
    end
  end
end
