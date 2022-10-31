


defmodule Oas.Members.MemberDetails do
  use Ecto.Schema
  import Ecto.Changeset
  

  schema "members_details" do
    field :phone, :string
    field :address, :string
    field :dob, :date
    field :agreed_to_tac, :boolean

    field :nok_name, :string
    field :nok_email, :string
    field :nok_phone, :string
    field :nok_address, :string

    belongs_to :members, Oas.Members.Member, foreign_key: :member_id

    timestamps()
  end

  defp validate_email(changeset) do
    changeset
    |> validate_required([:nok_email])
    |> validate_format(:nok_email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:nok_email, max: 160)
  end

  def changeset(memberDetails, params) do
    IO.puts("301 memberDetails changeset")
    IO.inspect(params)
    memberDetails
    |> cast(params, [:phone, :address, :dob, :agreed_to_tac, :nok_name, :nok_email, :nok_phone, :nok_address])
    |> validate_acceptance(:agreed_to_tac, message: "Please agree to above")
    |> validate_email
  end

end