defmodule OasWeb.Schema.TransactionSaveAtomicTest do
  # The admin "transaction" mutation saves the transaction, its tags and its
  # credit, then the membership and the auto tags. All of it must commit or
  # roll back together.
  use Oas.DataCase

  import Ecto.Query, only: [from: 2]

  alias Oas.Repo
  alias Oas.Transactions.{Transaction, TransactionTags, TransactionTagAuto}
  alias Oas.Members.{Membership, MembershipPeriod}
  alias Oas.Credits.Credit

  @mutation """
  mutation (
    $id: Int, $what: String!, $who: String, $who_member_id: Int,
    $membership_period_id: Int, $credit: CreditArg,
    $transaction_tags: [TransactionTagArg], $auto_tags: [TransactionTagArg]
  ) {
    transaction(
      id: $id, what: $what, when: "2025-02-01", who: $who,
      who_member_id: $who_member_id, type: "INCOMING", amount: 10.0,
      my_reference: "ref", membership_period_id: $membership_period_id,
      credit: $credit, transaction_tags: $transaction_tags, auto_tags: $auto_tags
    ) { id }
  }
  """

  defp run(variables) do
    Absinthe.run(@mutation, OasWeb.Schema,
      variables: variables,
      context: %{current_member: %{is_admin: true}}
    )
  end

  defp membership_period() do
    %MembershipPeriod{name: "2025", from: ~D[2025-01-01], to: ~D[2025-12-31], value: Decimal.new("12")}
    |> Repo.insert!()
  end

  defp count(queryable), do: Repo.aggregate(queryable, :count)

  describe "success" do
    test "saves the transaction, tags, credit, membership together" do
      member = Oas.MembersFixtures.member_fixture()
      period = membership_period()

      assert {:ok, %{data: %{"transaction" => %{"id" => id}}}} =
               run(%{
                 "what" => "Membership", "who" => member.name, "who_member_id" => member.id,
                 "membership_period_id" => period.id, "credit" => %{"amount" => 10.0},
                 "transaction_tags" => [%{"name" => "Membership"}]
               })

      transaction = Repo.get!(Transaction, id) |> Repo.preload([:credit, :membership, :transaction_tags])
      assert Decimal.equal?(transaction.credit.amount, Decimal.new("10"))
      assert transaction.membership.membership_period_id == period.id
      assert [%{name: "Membership"}] = transaction.transaction_tags
    end

    test "saves a transaction without a member and its auto tags" do
      assert {:ok, %{data: %{"transaction" => %{"id" => id}}}} =
               run(%{
                 "what" => "Hall hire", "who" => "The Hall",
                 "transaction_tags" => [%{"name" => "Venue"}],
                 "auto_tags" => [%{"name" => "Venue"}]
               })

      assert Repo.get!(Transaction, id)
      [tag] = Repo.all(TransactionTags)
      assert [%{who: "The Hall", transaction_tag_id: tag_id}] = Repo.all(TransactionTagAuto)
      assert tag_id == tag.id
    end

    test "removing the membership period removes the membership" do
      member = Oas.MembersFixtures.member_fixture()
      period = membership_period()
      base = %{"what" => "Membership", "who" => member.name, "who_member_id" => member.id}

      {:ok, %{data: %{"transaction" => %{"id" => id}}}} =
        run(Map.put(base, "membership_period_id", period.id))

      assert count(Membership) == 1
      assert {:ok, %{data: %{"transaction" => %{"id" => ^id}}}} = run(Map.put(base, "id", id))
      assert count(Membership) == 0
    end
  end

  describe "rollback when the membership fails" do
    test "a new transaction is not saved when the member already has that membership" do
      member = Oas.MembersFixtures.member_fixture()
      period = membership_period()
      %Membership{member_id: member.id, membership_period_id: period.id} |> Repo.insert!()

      assert {:ok, %{errors: [%{message: message}]}} =
               run(%{
                 "what" => "Membership", "who" => member.name, "who_member_id" => member.id,
                 "membership_period_id" => period.id, "credit" => %{"amount" => 10.0},
                 "transaction_tags" => [%{"name" => "Membership"}]
               })

      assert message =~ "already has a membership"
      assert count(Transaction) == 0
      assert count(Credit) == 0
      assert count(TransactionTags) == 0
      assert count(Membership) == 1
    end

    test "a new transaction is not saved when the membership period does not exist" do
      member = Oas.MembersFixtures.member_fixture()

      assert {:ok, %{errors: [%{message: "Membership period not found"}]}} =
               run(%{
                 "what" => "Membership", "who" => member.name, "who_member_id" => member.id,
                 "membership_period_id" => 999_999, "credit" => %{"amount" => 10.0}
               })

      assert count(Transaction) == 0
      assert count(Credit) == 0
    end

    test "a new transaction is not saved when a membership has no member" do
      period = membership_period()

      assert {:ok, %{errors: [%{message: message}]}} =
               run(%{"what" => "Membership", "who" => "Somebody", "membership_period_id" => period.id})

      assert message =~ "needs a member"
      assert count(Transaction) == 0
    end

    test "an edit is undone, including its tags and credit" do
      member = Oas.MembersFixtures.member_fixture()
      base = %{"who" => member.name, "who_member_id" => member.id}

      {:ok, %{data: %{"transaction" => %{"id" => id}}}} =
        run(Map.merge(base, %{
          "what" => "Original", "credit" => %{"amount" => 10.0},
          "transaction_tags" => [%{"name" => "Old"}]
        }))

      assert {:ok, %{errors: [_]}} =
               run(Map.merge(base, %{
                 "id" => id, "what" => "Edited", "membership_period_id" => 999_999,
                 "transaction_tags" => [%{"name" => "New"}]
               }))

      transaction = Repo.get!(Transaction, id) |> Repo.preload([:credit, :transaction_tags])
      assert transaction.what == "Original"
      assert Decimal.equal?(transaction.credit.amount, Decimal.new("10"))
      assert [%{name: "Old"}] = transaction.transaction_tags
      assert ["Old"] = Repo.all(from t in TransactionTags, select: t.name)
    end
  end

  describe "membership follows the transaction's member" do
    test "moving the transaction to another member moves its membership" do
      member = Oas.MembersFixtures.member_fixture()
      other = Oas.MembersFixtures.member_fixture()
      period = membership_period()

      {:ok, %{data: %{"transaction" => %{"id" => id}}}} =
        run(%{
          "what" => "Membership", "who" => member.name, "who_member_id" => member.id,
          "membership_period_id" => period.id
        })

      assert {:ok, %{data: %{"transaction" => %{"id" => ^id}}}} =
               run(%{
                 "id" => id, "what" => "Membership", "who" => other.name,
                 "who_member_id" => other.id, "membership_period_id" => period.id
               })

      assert [%{member_id: member_id, transaction_id: ^id}] = Repo.all(Membership)
      assert member_id == other.id
    end

    test "the move is undone when the other member already has that membership" do
      member = Oas.MembersFixtures.member_fixture()
      other = Oas.MembersFixtures.member_fixture()
      period = membership_period()
      %Membership{member_id: other.id, membership_period_id: period.id} |> Repo.insert!()

      {:ok, %{data: %{"transaction" => %{"id" => id}}}} =
        run(%{
          "what" => "Membership", "who" => member.name, "who_member_id" => member.id,
          "membership_period_id" => period.id
        })

      assert {:ok, %{errors: [%{message: message}]}} =
               run(%{
                 "id" => id, "what" => "Edited", "who" => other.name,
                 "who_member_id" => other.id, "membership_period_id" => period.id
               })

      assert message =~ "already has a membership"
      transaction = Repo.get!(Transaction, id) |> Repo.preload(:membership)
      assert transaction.what == "Membership"
      assert transaction.who_member_id == member.id
      assert transaction.membership.member_id == member.id
      assert count(Membership) == 2
    end

    test "a null membership period removes the membership" do
      member = Oas.MembersFixtures.member_fixture()
      period = membership_period()
      base = %{"what" => "Membership", "who" => member.name, "who_member_id" => member.id}

      {:ok, %{data: %{"transaction" => %{"id" => id}}}} =
        run(Map.put(base, "membership_period_id", period.id))

      assert {:ok, %{data: %{"transaction" => %{"id" => ^id}}}} =
               run(Map.merge(base, %{"id" => id, "membership_period_id" => nil}))

      assert count(Membership) == 0
    end
  end

  describe "auto tags" do
    test "an auto tag that is not one of the transaction's tags is ignored" do
      assert {:ok, %{data: %{"transaction" => %{"id" => id}}}} =
               run(%{
                 "what" => "Hall hire", "who" => "The Hall",
                 "transaction_tags" => [%{"name" => "Venue"}],
                 "auto_tags" => [%{"name" => "Venue"}, %{"name" => "Removed"}]
               })

      assert Repo.get!(Transaction, id)
      assert ["Venue"] = Repo.all(from t in TransactionTags, select: t.name)
      assert [%{who: "The Hall"}] = Repo.all(TransactionTagAuto)
    end

    test "renaming the only transaction for a who deletes the old who's auto tags" do
      {:ok, %{data: %{"transaction" => %{"id" => id}}}} =
        run(%{
          "what" => "Hall hire", "who" => "The Hall",
          "transaction_tags" => [%{"name" => "Venue"}, %{"name" => "Rent"}],
          "auto_tags" => [%{"name" => "Venue"}, %{"name" => "Rent"}]
        })

      assert count(TransactionTagAuto) == 2

      # Rent is dropped from the transaction, so only the rename can remove it.
      assert {:ok, %{data: %{"transaction" => %{"id" => ^id}}}} =
               run(%{
                 "id" => id, "what" => "Hall hire", "who" => "Another Hall",
                 "transaction_tags" => [%{"name" => "Venue"}],
                 "auto_tags" => [%{"name" => "Venue"}]
               })

      assert [%{who: "Another Hall"}] = Repo.all(TransactionTagAuto)
    end

    test "renaming keeps the old who's auto tags while another transaction has that who" do
      base = %{
        "what" => "Hall hire", "who" => "The Hall",
        "transaction_tags" => [%{"name" => "Venue"}],
        "auto_tags" => [%{"name" => "Venue"}]
      }

      {:ok, %{data: %{"transaction" => %{"id" => id}}}} = run(base)
      {:ok, _} = run(base)

      assert {:ok, %{data: %{"transaction" => %{"id" => ^id}}}} =
               run(Map.merge(base, %{"id" => id, "who" => "Another Hall"}))

      assert ["Another Hall", "The Hall"] =
               Repo.all(from ta in TransactionTagAuto, select: ta.who, order_by: ta.who)
    end

    test "an edit that leaves who out keeps the saved who for its auto tags" do
      {:ok, %{data: %{"transaction" => %{"id" => id}}}} =
        run(%{"what" => "Original", "who" => "The Hall", "transaction_tags" => [%{"name" => "Venue"}]})

      assert {:ok, %{data: %{"transaction" => %{"id" => ^id}}}} =
               run(%{
                 "id" => id, "what" => "Edited",
                 "transaction_tags" => [%{"name" => "Venue"}],
                 "auto_tags" => [%{"name" => "Venue"}]
               })

      assert Repo.get!(Transaction, id).what == "Edited"
      assert [%{who: "The Hall"}] = Repo.all(TransactionTagAuto)
    end

    test "an edit that leaves the member out does not auto tag a member's transaction" do
      member = Oas.MembersFixtures.member_fixture()

      {:ok, %{data: %{"transaction" => %{"id" => id}}}} =
        run(%{"what" => "Original", "who" => member.name, "who_member_id" => member.id})

      assert {:ok, %{data: %{"transaction" => %{"id" => ^id}}}} =
               run(%{
                 "id" => id, "what" => "Edited", "who" => member.name,
                 "transaction_tags" => [%{"name" => "Fees"}],
                 "auto_tags" => [%{"name" => "Fees"}]
               })

      assert Repo.get!(Transaction, id).who_member_id == member.id
      assert count(TransactionTagAuto) == 0
    end
  end

  describe "rollback when a later step raises" do
    test "a new transaction is not saved" do
      # A tag id that does not exist makes the save raise part-way through.
      assert_raise Ecto.NoResultsError, fn ->
        run(%{
          "what" => "Hall hire", "who" => "The Hall",
          "transaction_tags" => [%{"id" => 999_999, "name" => "Gone"}]
        })
      end

      assert count(Transaction) == 0
    end
  end

  test "an invalid transaction still returns its validation error" do
    assert {:ok, %{errors: [%{message: message}]}} =
             run(%{"what" => "No who"})

    assert message =~ "who"
    assert count(Transaction) == 0
  end
end
