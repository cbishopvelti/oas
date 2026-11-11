defmodule OasWeb.Schema.ImportMembersTest do
  use Oas.DataCase

  import Swoosh.TestAssertions

  alias Oas.Members.Member
  alias Oas.Transactions.Transaction

  @admin %{current_member: %{is_admin: true, is_reviewer: false, is_active: true}}
  @reviewer %{current_member: %{is_admin: false, is_reviewer: true, is_active: true}}

  @import """
  mutation ($rows: [MemberImportRowArg!]!, $dry_run: Boolean!) {
    import_members(rows: $rows, dry_run: $dry_run) {
      saved create_count skip_count error_count opening_credit_total
      rows { row name email opening_credit outcome reason member_id transaction_id }
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

  defp transaction_count, do: Repo.aggregate(Transaction, :count)
  defp credit_count, do: Repo.aggregate(Oas.Credits.Credit, :count)

  describe "opening credit" do
    test "creates an opening balance transaction and credit" do
      result =
        import!(
          [
            %{"name" => "Ann Smith", "email" => "ann@example.com", "opening_credit" => " 12.50 "},
            %{"name" => "Bob Jones", "email" => "bob@example.com", "opening_credit" => "3"}
          ],
          false
        )

      assert %{"saved" => true, "create_count" => 2, "opening_credit_total" => "15.50"} = result
      [ann_row, bob_row] = result["rows"]
      assert ann_row["opening_credit"] == "12.50"

      ann = Repo.get_by!(Member, email: "ann@example.com")

      transaction =
        Repo.get!(Transaction, ann_row["transaction_id"]) |> Repo.preload(:credit)

      assert transaction.what == "Opening balance"
      assert transaction.type == "INCOMING"
      assert transaction.who == "Ann Smith"
      assert transaction.who_member_id == ann.id
      assert transaction.when == Oas.Settings.today()
      assert Decimal.equal?(transaction.amount, "12.50")
      assert transaction.my_reference == "opening-balance-member-#{ann.id}"
      assert Decimal.equal?(transaction.credit.amount, "12.50")
      assert transaction.credit.who_member_id == ann.id

      bob_transaction = Repo.get!(Transaction, bob_row["transaction_id"])
      assert bob_transaction.my_reference != transaction.my_reference

      {_credits, total} = Oas.Credits.Credit2.get_credit_amount(%{member_id: ann.id})
      assert Decimal.equal?(total, "12.50")
    end

    test "zero or blank opening credit creates no transaction" do
      before = transaction_count()

      result =
        import!(
          [
            %{"name" => "Ann Smith", "email" => "ann@example.com", "opening_credit" => "0"},
            %{"name" => "Bob Jones", "email" => "bob@example.com", "opening_credit" => ""},
            %{"name" => "Cat Brown", "email" => "cat@example.com"}
          ],
          false
        )

      assert %{"saved" => true, "create_count" => 3, "opening_credit_total" => "0"} = result
      assert Enum.all?(result["rows"], &(&1["transaction_id"] == nil))
      assert transaction_count() == before
    end

    test "a bad amount is reported in the dry run" do
      result =
        import!(
          [
            %{"name" => "Ann Smith", "email" => "ann@example.com", "opening_credit" => "-5"},
            %{"name" => "Bob Jones", "email" => "bob@example.com", "opening_credit" => "ten"},
            %{"name" => "Cat Brown", "email" => "cat@example.com", "opening_credit" => "1.234"},
            %{"name" => "Dan Green", "email" => "dan@example.com", "opening_credit" => "7.5"}
          ],
          true
        )

      reason = "Invalid opening credit (use a number of 0 or more, like 12.50)"

      assert Enum.map(result["rows"], &{&1["outcome"], &1["reason"], &1["opening_credit"]}) == [
               {"ERROR", reason, nil},
               {"ERROR", reason, nil},
               {"ERROR", reason, nil},
               {"CREATE", nil, "7.5"}
             ]

      assert %{"saved" => false, "error_count" => 3, "opening_credit_total" => "7.5"} = result
    end

    test "existing members are skipped without credit" do
      existing_member()
      before = transaction_count()

      result =
        import!(
          [%{"name" => "Someone", "email" => "existing@example.com", "opening_credit" => "10"}],
          false
        )

      assert [%{"outcome" => "SKIP", "reason" => "A member with this email already exists; opening credit not added"}] =
               result["rows"]

      assert transaction_count() == before
    end

    test "a failed insert rolls back members and credits together" do
      before = {member_count(), transaction_count(), credit_count()}

      rows = [
        %{name: "Ann Smith", email: "ann@example.com", opening_credit: "20"},
        %{name: "Bob Jones", email: "bob@example.com", opening_credit: "5"}
      ]

      {:ok, _} =
        Ecto.Adapters.SQL.query(
          Repo,
          """
          CREATE TRIGGER import_credit_test_block BEFORE INSERT ON transactions
          WHEN NEW.who = 'Bob Jones'
          BEGIN SELECT RAISE(ABORT, 'blocked by test'); END
          """,
          []
        )

      assert_raise Exqlite.Error, fn -> Oas.Members.Import.run(rows, dry_run: false) end
      assert {member_count(), transaction_count(), credit_count()} == before
    end
  end
end
