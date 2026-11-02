defmodule OasWeb.Schema.SaveCreditAmountTest do
  use Oas.DataCase

  @mutation """
  mutation ($id: Int!, $amount: String!) {
    save_credit_amount(id: $id, amount: $amount) { success }
  }
  """

  defp run(credit, amount) do
    Absinthe.run(@mutation, OasWeb.Schema,
      variables: %{"id" => credit.id, "amount" => amount},
      context: %{current_member: %{is_admin: true}}
    )
  end

  test "updates a credit that is not linked to an attendance" do
    member = Oas.MembersFixtures.member_fixture()

    credit =
      %Oas.Credits.Credit{what: "Thing", amount: Decimal.new("-5"), when: ~D[2025-01-01], who_member_id: member.id}
      |> Oas.Repo.insert!()

    assert {:ok, %{data: %{"save_credit_amount" => %{"success" => true}}}} = run(credit, "-7.5")
    assert Decimal.equal?(Oas.Repo.get!(Oas.Credits.Credit, credit.id).amount, Decimal.new("-7.5"))
  end
end
