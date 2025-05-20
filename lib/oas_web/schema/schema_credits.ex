import Ecto.Query, only: [from: 2]
defmodule OasWeb.Schema.SchemaCredits do
  use Absinthe.Schema.Notation

  object :credit do
    field :id, :integer
    field :what, :string
    field :when, :string
    field :expires_on, :string
    field :amount, :string
    field :after_amount, :string
    field :who_member_id, :integer
    field :member, :member
    field :transaction, :transaction
    field :debit, :credit
    field :credit, :credit
    field :membership, :membership
    field :attendance, :attendance
    field :thing_id, :integer
  end

  object :credits_queries do
    field :credits, list_of(:credit) do
      arg :member_id, :integer
      resolve fn _, %{member_id: member_id}, _ ->
        # result = from(c in Oas.Credits.Credit,
        #   preload: [:transaction, ],
        #   where: c.who_member_id == ^member_id, order_by: [desc: c.when, desc: c.id]
        # )
        # |> Oas.Repo.all()
        {credits, _} = Oas.Credits.Credit.get_credit_amount(%{member_id: member_id})

        {:ok, credits}
      end
    end

    field :public_credits, list_of(:credit) do
      arg :email, non_null(:string)

      resolve fn _, %{email: email}, _ ->
        member = from(
          m in Oas.Members.Member,
          where: m.email == ^email,
          limit: 1
        ) |> Oas.Repo.one!()

        {credits, _} = Oas.Credits.Credit.get_credit_amount(%{member_id: member.id})
        {:ok, credits}
      end
    end
  end

  object :credits_mutations do
    field :delete_credit, :success do
      arg :id, non_null(:integer)
      resolve fn _, %{id: id}, _ ->
        Oas.Repo.get!(Oas.Credits.Credit, id)
        |> Oas.Repo.delete!()
        {:ok, %{success: true}}
      end
    end
    field :transfer_credit, :success do
      arg :from_member_id, non_null(:integer)
      arg :to_member_id, non_null(:integer)
      arg :amount, non_null(:string)
      resolve fn _, %{from_member_id: from_member_id, to_member_id: to_member_id, amount: amount}, _ ->
        if (Decimal.lt?(amount, 0) ) do
          raise "Negative numbers not allowed"
        end
        {trans, _} = Oas.Credits.Credit.get_credit_amount(%{member_id: from_member_id})
        # Find date to use
        {weighted_data, _, _} = trans
        |> Enum.reverse()
        |> Enum.filter(fn tran -> Decimal.gt?(tran.amount, "0.0")  end)
        |> Enum.reduce_while({[], amount, 0}, fn (credit, {accData, amount, usedAmount}) ->
          newAmount = Decimal.sub(amount, Decimal.sub(credit.after_amount, usedAmount))
          {cont, newAccData} = if Decimal.lt?(newAmount, "0.0") do
            {:halt, { amount, credit.when}}
          else
            {:cont, {Decimal.sub(credit.after_amount, usedAmount), credit.when}}
          end

          {
            cont,
            {[newAccData | accData], newAmount, Decimal.add(usedAmount, newAmount)}
          }
        end)

        # Average
        {sumprod, sum} = Enum.reduce(weighted_data, {0.0, 0.0}, fn {amount, date}, {sumprod, sum} ->
          {
            ((date |> Date.to_gregorian_days()) * (amount |> Decimal.to_float())) + sumprod,
            (amount |> Decimal.to_float()) + sum
          }
        end)
        now = Date.utc_today()
        average_date = case sum do
          +0.0 -> now
          -0.0 -> now
          sum -> Date.from_gregorian_days(round(sumprod / sum))
        end

        now = Date.utc_today()
        config = from(cc in Oas.Config.Config, select: cc) |> Oas.Repo.one

        debit = %Oas.Credits.Credit{}
        |> Ecto.Changeset.cast(%{
            amount: Decimal.sub("0.0", amount),
            when: now,
            what: "To #{Oas.Repo.get!(Oas.Members.Member, to_member_id).name}",
            who_member_id: from_member_id
        }, [:when, :what, :amount, :who_member_id])

        %Oas.Credits.Credit{}
        |> Ecto.Changeset.cast(%{
          amount: Decimal.new(amount),
          when: now,
          what: "From #{Oas.Repo.get!(Oas.Members.Member, from_member_id).name}",
          expires_on: Date.add(average_date, config.token_expiry_days),
          who_member_id: to_member_id
        }, [:amount, :when, :what, :expires_on, :who_member_id])
        |> Ecto.Changeset.put_assoc(:credit, debit)
        |> Oas.Repo.insert!()

        {:ok, %{
          success: true
        }}
      end
    end

    field :save_credit_amount, type: :success do
      arg :id, non_null(:integer)
      arg :amount, non_null(:string)
      resolve fn _, args, _ ->
        %{sign: -1} = amount = Decimal.new(args.amount)

        Oas.Repo.get!(Oas.Credits.Credit, args.id)
        |> Ecto.Changeset.cast(%{
          amount: amount
        },
          [:amount]
        )
        |> Oas.Repo.update()
        {:ok, %{sucess: true}}
      end
    end
  end
end
