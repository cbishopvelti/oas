defmodule OasWeb.Schema.ImportMembersTest do
  use Oas.DataCase

  import Swoosh.TestAssertions

  alias Oas.Members.Member

  @admin %{current_member: %{is_admin: true, is_reviewer: false, is_active: true}}
  @reviewer %{current_member: %{is_admin: false, is_reviewer: true, is_active: true}}

  @import """
  mutation ($rows: [MemberImportRowArg!]!, $dry_run: Boolean!) {
    import_members(rows: $rows, dry_run: $dry_run) {
      saved create_count skip_count error_count
      rows { row name email outcome reason member_id }
    }
  }
  """

  defp run_import(rows, dry_run, context \\ @admin) do
    Absinthe.run(@import, OasWeb.Schema,
      variables: %{"rows" => rows, "dry_run" => dry_run},
      context: context
    )
  end

  defp import!(rows, dry_run) do
    {:ok, %{data: %{"import_members" => result}}} = run_import(rows, dry_run)
    result
  end

  defp member_count, do: Repo.aggregate(Member, :count)

  defp existing_member do
    {:ok, member} =
      Oas.Members.new_member_changeset(%{name: "Existing Person", email: "Existing@Example.com"})
      |> Repo.insert()

    member
  end

  test "dry run reports outcomes and saves nothing" do
    before = member_count()

    result =
      import!(
        [
          %{"name" => " Ann Smith ", "email" => " ann@example.com "},
          %{"name" => "Bob Jones", "email" => "bob@example.com"}
        ],
        true
      )

    assert %{"saved" => false, "create_count" => 2, "skip_count" => 0, "error_count" => 0} = result
    assert [%{"row" => 1, "name" => "Ann Smith", "email" => "ann@example.com", "outcome" => "CREATE"}, _] = result["rows"]
    assert member_count() == before
    assert_no_email_sent()
  end

  test "invalid rows and duplicates are reported" do
    existing_member()

    result =
      import!(
        [
          %{"name" => "", "email" => "noname@example.com"},
          %{"name" => "No Email", "email" => ""},
          %{"name" => "Bad Email", "email" => "not-an-email"},
          %{"name" => "Already Here", "email" => "  existing@EXAMPLE.com "},
          %{"name" => "Carol", "email" => "carol@example.com"},
          %{"name" => "Carol Again", "email" => "CAROL@example.com"},
          %{"name" => "carol", "email" => "carol2@example.com"},
          %{"name" => "existing person", "email" => "someone@example.com"}
        ],
        true
      )

    outcomes = Enum.map(result["rows"], &{&1["outcome"], &1["reason"]})

    assert outcomes == [
             {"ERROR", "Missing name"},
             {"ERROR", "Missing email"},
             {"ERROR", "Invalid email"},
             {"SKIP", "A member with this email already exists"},
             {"CREATE", nil},
             {"ERROR", "Duplicate email in file (same as row 5)"},
             {"ERROR", "Duplicate name in file (same as row 5)"},
             {"ERROR", "A member with this name already exists"}
           ]

    assert %{"create_count" => 1, "skip_count" => 1, "error_count" => 6} = result
  end

  test "real import creates valid rows and skips existing members untouched" do
    member = existing_member()
    before = member_count()

    result =
      import!(
        [
          %{"name" => "Ann Smith", "email" => "ann@example.com"},
          %{"name" => "Someone Else", "email" => "existing@example.com"}
        ],
        false
      )

    assert %{"saved" => true, "create_count" => 1, "skip_count" => 1, "error_count" => 0} = result
    assert member_count() == before + 1

    ann = Repo.get_by!(Member, email: "ann@example.com")
    assert ann.name == "Ann Smith"
    assert ann.hashed_password != nil
    assert hd(result["rows"])["member_id"] == ann.id

    assert Repo.get!(Member, member.id) == member
    assert_no_email_sent()
  end

  test "a row with an error rolls back the whole import" do
    before = member_count()

    result =
      import!(
        [
          %{"name" => "Ann Smith", "email" => "ann@example.com"},
          %{"name" => "Bad Email", "email" => "nope"}
        ],
        false
      )

    assert %{"saved" => false, "create_count" => 1, "error_count" => 1} = result
    assert member_count() == before
    assert Repo.get_by(Member, email: "ann@example.com") == nil
    assert_no_email_sent()
  end

  test "a failed insert rolls back rows already inserted" do
    before = member_count()

    rows = [
      %{name: "Ann Smith", email: "ann@example.com"},
      %{name: "Bob Jones", email: "bob@example.com"}
    ]

    # Simulate someone registering bob@example.com between the check and the
    # insert: the database rejects the second insert after the first succeeded.
    {:ok, _} =
      Ecto.Adapters.SQL.query(
        Repo,
        """
        CREATE TRIGGER import_test_block BEFORE INSERT ON members
        WHEN NEW.email = 'bob@example.com'
        BEGIN SELECT RAISE(ABORT, 'UNIQUE constraint failed: members.email'); END
        """,
        []
      )

    result = Oas.Members.Import.run(rows, dry_run: false)

    assert result.saved == false
    assert [%{outcome: :create}, %{outcome: :error, reason: "email has already been taken"}] = result.rows
    assert member_count() == before
  end

  test "only admins can import" do
    assert {:ok, %{errors: [_ | _]}} =
             run_import([%{"name" => "Ann", "email" => "ann@example.com"}], false, @reviewer)

    assert Repo.get_by(Member, email: "ann@example.com") == nil
  end
end
