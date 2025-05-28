import Ecto.Query, only: [from: 2]

defmodule Oas.TokenMailer do
  use Swoosh.Mailer, otp_app: :oas

  # SO TOKENS
  def maybe_send_warnings_email(member) do
    lastTransaction = from(t in Oas.Transactions.Transaction,
      order_by: [desc: t.when, desc: t.id],
      limit: 1
    ) |> Oas.Repo.one

    attendance = from(a in Oas.Trainings.Attendance,
      inner_join: m in assoc(a, :member),
      inner_join: tr in assoc(a, :training),
      preload: [:token, training: tr],
      where: m.id == ^member.id,
      order_by: [desc: tr.when, desc: a.id],
      limit: 2
    ) |> Oas.Repo.all

    case attendance do
      [_firstAttendance, %{token: nil, training: %{when: when1}}] when when1 > lastTransaction.when  ->
        nil
      _ ->
        config = from(c in Oas.Config.Config, limit: 1) |> Oas.Repo.one!()
        case config.credits do
          true -> nil #TODO
          false -> maybe_send_warnings_email_2(member)
        end
    end

  end

  def maybe_send_warnings_email_2(member) do

    warnings = []
    tokens = Oas.Attendance.get_token_amount(%{member_id: member.id})

    last_transaction = from(tra in Oas.Transactions.Transaction,
      select: max(tra.when)
    ) |> Oas.Repo.one

    warnings = if (tokens <= 0) do
      ["You have run out of tokens (#{tokens}), please buy more.\n(If you bought tokens since #{last_transaction}, please ignore)" | warnings]
    else
      warnings
    end

    warnings = case Oas.Attendance.check_membership(member) do
      {_, :not_member} -> ["You are not a valid member, please pay for membership" | warnings]
      {_, :x_member} -> ["You are not a valid member, please pay for membership" | warnings]
      _ -> warnings
    end

    case (warnings) do
      [] -> nil
      warnings ->
        config = from(cc in Oas.Config.Config, select: cc) |> Oas.Repo.one
        Oas.Tokens.TokenNotifier.deliver(member.email, "#{config.name} notification",
        """
        Hi #{member.name}

        #{Enum.join(warnings, "\n")}

        Thanks

        #{config.name}
        """)
    end
  end
  # EO TOKENS

  # SO CREDITS
  def should_send_warning(last_transaction, credits) do
    last_debits = credits |> Enum.filter(fn %{amount: amount, when: when1} ->
      Decimal.lt?(amount, "0.0")
        && (Enum.member?([:gt], Date.compare(when1, last_transaction)))
    end)

    IO.inspect(last_debits, label: "006")

    case last_debits do
      [_a] -> true
      [_a, b | _rest] -> cond do
        # Second credit is greater than 0.0 so a warning wouldn't have been sent
        Decimal.gte?(b.after_amount, "0.0") -> true
        # There have been transactions after the previous warning and still negative so send another warning
        # Date.after?(last_transaction, b.when) -> true
        true -> false
      end
      _ -> false
    end
  end
  def maybe_send_credits_warning(member) do
    {credits, total_amount} = Oas.Credits.Credit2.get_credit_amount(%{member_id: member.id})

    last_transaction = from(tra in Oas.Transactions.Transaction,
      select: max(tra.when)
    ) |> Oas.Repo.one

    cond do
      Decimal.lt?(total_amount, "0.0") && should_send_warning(last_transaction, credits) ->
        send_credits_warning(member, last_transaction)
      true -> nil
    end
  end
  def send_credits_warning(member, last_transaction) do
    config = from(cc in Oas.Config.Config, select: cc) |> Oas.Repo.one

    # last_two_cerdits = from(c from Oas.Credits.Credit,
    #   where: c.member_id == ^member.id and amount < 0
    # )


    href = "#{Application.fetch_env!(:oas, :public_url)}/credits"

    Oas.Tokens.TokenNotifier.deliver(member.email, "#{config.name} notification",
    """
    Hi #{member.name}

    You have run out of credits, please check your credit balance at: #{href} and top up.

    (If you bought tokens since #{last_transaction}, please ignore)

    Thanks

    #{config.name}
    """)
  end
  # EO CREDITS
end
