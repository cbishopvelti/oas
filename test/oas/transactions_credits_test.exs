defmodule Oas.TransactionsCreditsTest do
  use Oas.DataCase


  defp doCredit(amount, when1, member) do


    transaction = %Oas.Transactions.Transaction{}
    |> Ecto.Changeset.cast(%{
      who: member.name,
      who_member_id: member.id,
      what: "Credit",
      amount: Decimal.new(amount),
      when: when1, # Date.from_iso8601!("2025-02-01"),
      type: (if amount > 0, do: "INCOMING", else: "OUTGOING"),
      my_reference: "test reference"
    }, [
      :who, :who_member_id, :what,
      :amount, :when, :type,
      :my_reference
    ])
    |> Oas.Gocardless.TransactionsCredits.generate_transaction_credits_2(%{
      transaction_tags: []
    })
    |> Oas.Repo.insert!()
  end

  describe("transactions_credits") do

    @tag only: true
    test("User doesn't pay enough to cover tokens") do
      IO.inspect(Application.get_env(:oas, Oas.Repo), label: "001")
      config = from(cc in Oas.Config.Config, select: cc) |> Oas.Repo.one

      %{id: member_id, name: name} = member = Oas.MembersFixtures.member_fixture()

      # IO.inspect(config, label: "002 config")
      # Create test where
      {:ok, training_where} = %Oas.Trainings.TrainingWhere{}
      |> Oas.Trainings.TrainingWhere.changeset(%{
        name: "test where",
        credit_amount: 4.5
      })
      |> Oas.Repo.insert()

      # Create test training
      {:ok, training} = %Oas.Trainings.Training{}
      |> Ecto.Changeset.cast(%{when: Date.from_iso8601!("2025-10-03"), notes: ""}, [:when, :notes])
      |> Ecto.Changeset.put_assoc(:training_where, training_where)
      |> Oas.Repo.insert()

      # IO.inspect(training, label: "004")

      attendance = Oas.Attendance.add_attendance(%{
        member_id: member_id,
        training_id: training.id
      }, %{inserted_by_member_id: member_id})

      # IO.inspect(attendance, label: "005 attendance")

      config
      |> Ecto.Changeset.cast(%{credits: true}, [:credits])
      |> Oas.Repo.update()

      # ---------------
      # RUN IT

      result = doCredit(
        "2",
        Date.from_iso8601!("2025-10-03"),
        member
      )
      IO.inspect(result, label: "006 doCredit")


    end

  end

end
