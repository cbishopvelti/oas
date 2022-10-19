defmodule OasWeb.MemberRegistrationController do
  use OasWeb, :controller

  alias Oas.Members
  alias Oas.Members.Member
  alias OasWeb.MemberAuth

  def new(conn, _params) do
    changeset = Members.change_member_registration(%Member{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"member" => member_params}) do
    case Members.register_member(member_params) do
      {:ok, member} ->
        {:ok, _} =
          Members.deliver_member_confirmation_instructions(
            member,
            &Routes.member_confirmation_url(conn, :edit, &1)
          )

        conn
        |> put_flash(:info, "Member created successfully.")
        |> MemberAuth.log_in_member(member)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
end
