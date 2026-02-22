defmodule Oas.CreditsTest do
  use Oas.DataCase

  describe "credits" do
    # mix test --only only
    # @tag only: true
    test "Adds up credits" do
      # Ecto.Adapters.SQL.Sandbox.checkout(Oas.Repo, sandbox: false)
      {transaction, member} = Oas.TransactionFixtures.transaction_fixture()

      # expired credits
      income1 =
        %Oas.Credits.Credit{}
        |> Ecto.Changeset.cast(
          %{
            what: "Stuff",
            amount: Decimal.new("3.0"),
            when: Date.from_iso8601!("2025-02-01"),
            expires_on: Date.from_iso8601!("2025-02-01")
          },
          [:what, :amount, :when, :expires_on]
        )
        |> Ecto.Changeset.put_assoc(:transaction, transaction)
        |> Ecto.Changeset.put_assoc(:member, member)
        |> Oas.Repo.insert!()

      _income2 =
        %Oas.Credits.Credit{}
        |> Ecto.Changeset.cast(
          %{
            what: "Stuff",
            amount: Decimal.new("3.0"),
            when: Date.from_iso8601!("2025-02-01"),
            expires_on: Date.from_iso8601!("2025-02-03")
          },
          [:what, :amount, :when, :expires_on]
        )
        |> Ecto.Changeset.put_assoc(:transaction, transaction)
        |> Ecto.Changeset.put_assoc(:member, member)
        |> Oas.Repo.insert!()

      _used =
        %Oas.Credits.Credit{}
        |> Ecto.Changeset.cast(
          %{
            what: "Stuff2",
            amount: Decimal.new("-2.0"),
            when: Date.from_iso8601!("2025-02-02"),
            expires_on: nil
          },
          [:what, :amount, :when, :expires_on]
        )
        |> Ecto.Changeset.put_assoc(:transaction, transaction)
        |> Ecto.Changeset.put_assoc(:member, member)
        # |> Ecto.Changeset.put_assoc(:uses, [income1])
        |> Ecto.Changeset.put_assoc(:uses_credits_credits, [
          %{
            uses: income1,
            amount: Decimal.new("-2.0")
          }
        ])
        |> Oas.Repo.insert!()

      now = Date.from_iso8601!("2025-02-02")

      credits = Oas.Credits.Credit.get_credits(member, now)
      # {credits, _total} = Oas.Credits.Credit.get_credit_amount(%{member_id: member.id})

      result =
        credits
        |> Enum.reduce(Decimal.new("0.0"), fn {_, sum}, acc ->
          Decimal.add(acc, sum)
        end)

      assert Decimal.eq?(result, 3)
    end

    # @tag only: true
    test "One credit" do
      t1 = %{
        id: 1,
        amount: Decimal.new("2.0"),
        expires_on: Date.from_iso8601!("2025-02-01")
      }

      result =
        Oas.Credits.Credit.process_credits([t1])
        |> elem(0)
        |> List.last()
        |> Map.get(:after_amount)

      assert Decimal.eq?(Decimal.new("2"), result)
    end

    # @tag only: true
    test "Two credits" do
      data = [
        %{
          id: 1,
          amount: Decimal.new("2.0"),
          expires_on: Date.from_iso8601!("2025-02-01")
        },
        %{
          id: 2,
          amount: Decimal.new("2.0"),
          expires_on: Date.from_iso8601!("2025-02-02")
        }
      ]

      result =
        Oas.Credits.Credit.process_credits(data)
        |> elem(0)
        |> List.last()
        |> Map.get(:after_amount)

      assert Decimal.eq?(Decimal.new("4"), result)
    end

    test "Two credits and subctract" do
      data = [
        %{
          id: 1,
          amount: Decimal.new("2.0"),
          expires_on: Date.from_iso8601!("2025-02-03")
        },
        %{
          id: 2,
          amount: Decimal.new("1.0"),
          expires_on: Date.from_iso8601!("2025-02-04")
        },
        %{
          id: 3,
          amount: Decimal.new("-2.0"),
          when: Date.from_iso8601!("2025-02-01")
        }
      ]

      result =
        Oas.Credits.Credit.process_credits(data)
        |> elem(0)
        |> List.last()
        |> Map.get(:after_amount)

      assert Decimal.eq?(Decimal.new("1"), result)
    end

    # @tag only: true
    test "Two credits and subctract between" do
      data = [
        %{
          id: 1,
          amount: Decimal.new("2.0"),
          expires_on: Date.from_iso8601!("2025-02-03")
        },
        %{
          id: 2,
          amount: Decimal.new("-3.0"),
          when: Date.from_iso8601!("2025-02-02")
        },
        %{
          id: 3,
          amount: Decimal.new("2.0"),
          expires_on: Date.from_iso8601!("2025-02-05")
        }
      ]

      result =
        Oas.Credits.Credit.process_credits(data)
        |> elem(0)
        |> List.last()
        |> Map.get(:after_amount)

      assert Decimal.eq?(Decimal.new("1"), result)
    end

    # @tag only: true
    test "Pay off debt" do
      data = [
        %{
          id: 1,
          amount: Decimal.new("-3.0"),
          when: Date.from_iso8601!("2025-02-02")
        },
        %{
          id: 2,
          amount: Decimal.new("3.0"),
          expires_on: Date.from_iso8601!("2025-02-03")
        }
      ]

      result =
        Oas.Credits.Credit.process_credits(data)
        |> elem(0)
        |> List.last()
        |> Map.get(:after_amount)

      assert Decimal.eq?(Decimal.new("0"), result)
    end

    # @tag only: true
    test "Get credits in correct order" do
      {transaction, member} = Oas.TransactionFixtures.transaction_fixture()

      %Oas.Credits.Credit{}
      |> Ecto.Changeset.cast(
        %{
          what: "credit",
          amount: Decimal.new("3.0"),
          when: Date.from_iso8601!("2025-02-01"),
          expires_on: Date.from_iso8601!("2025-02-03")
        },
        [:what, :amount, :when, :expires_on]
      )
      |> Ecto.Changeset.put_assoc(:transaction, transaction)
      |> Ecto.Changeset.put_assoc(:member, member)
      |> Oas.Repo.insert!()

      %Oas.Credits.Credit{}
      |> Ecto.Changeset.cast(
        %{
          what: "debit",
          amount: Decimal.new("-2.0"),
          when: Date.from_iso8601!("2025-02-02")
        },
        [:what, :amount, :when, :expires_on]
      )
      |> Ecto.Changeset.put_assoc(:transaction, transaction)
      |> Ecto.Changeset.put_assoc(:member, member)
      |> Oas.Repo.insert!()

      [c0, c1] =
        from(c in Oas.Credits.Credit,
          where: c.who_member_id == ^member.id,
          order_by: [
            asc: coalesce(c.expires_on, c.when),
            asc_nulls_first: c.expires_on,
            asc: c.id
          ]
        )
        |> Oas.Repo.all()

      assert(Decimal.eq?(c0.amount, -2))
      assert(Decimal.eq?(c1.amount, 3))
    end

    test "deduct_debit handles expired credits" do
      # Create test data
      # We'll create a credit (positive amount) that has expired
      today = ~D[2025-02-24]
      yesterday = Date.add(today, -1)
      last_week = Date.add(today, -7)

      # An expired credit
      expired_credit = %{
        amount: Decimal.new("50.00"),
        expires_on: yesterday,
        when: last_week
      }

      # A debit (negative amount) to apply
      debit = %{
        amount: Decimal.new("-30.00"),
        when: today
      }

      # Create a ledger with the expired credit
      ledger = [expired_credit]

      # Set the current date for the test
      opts = %{now: today}

      # Call the function we're testing
      result = Oas.Credits.Credit.deduct_debit(ledger, debit, opts)

      # The expected result is that the expired credit remains untouched
      # and the debit is added to the end of the list
      expected = [expired_credit, debit]

      assert result == expected

      # Verify the total amount in the resulting ledger
      total =
        Enum.reduce(result, Decimal.new("0"), fn %{amount: amount}, acc ->
          Decimal.add(acc, amount)
        end)

      # Expected total: 50.00 + (-30.00) = 20.00
      assert Decimal.eq?(total, Decimal.new("20.00"))
    end

    # @tag only: true
    test "process_credits handles multiple expired and non-expired credits" do
      today = ~D[2025-02-24]
      yesterday = Date.add(today, -1)
      last_week = Date.add(today, -7)

      # Credits and debits to process
      credits = [
        # A debit
        %{
          amount: Decimal.new("-30.00"),
          when: today
        },
        # Another debit
        %{
          amount: Decimal.new("-20.00"),
          when: today
        }
      ]

      # Initial ledger with an expired credit
      [
        %{
          amount: Decimal.new("50.00"),
          expires_on: yesterday,
          when: last_week
        }
      ]

      # Mock the deduct_debit function if needed, or test the entire process_credits
      # This assumes you've made the necessary modifications to process_credits
      # to handle the opts parameter as discussed

      # Call the function
      {transactions, final_balance} = Oas.Credits.Credit.process_credits(credits)

      # Assert the resulting transactions have the correct after_amount values
      assert length(transactions) == 2

      # Verify the after_amount of each transaction
      # Assuming the debits are processed in order:
      # First debit: 50.00 - 30.00 = 20.00
      # Second debit: 20.00 - 20.00 = 0.00
      [first_trans, second_trans] = transactions
      assert Decimal.eq?(Map.get(first_trans, :after_amount), Decimal.new("-30.00"))
      assert Decimal.eq?(Map.get(second_trans, :after_amount), Decimal.new("-50.00"))

      # Verify the final balance
      assert Decimal.eq?(final_balance, Decimal.new("-50.00"))
    end
  end
end
