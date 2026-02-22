import Ecto.Query, only: [from: 2]

defmodule Oas.Members.Member do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :name, :is_admin, :is_reviewer, :inserted_at, :updated_at]}

  schema "members" do
    field :email, :string
    field :name, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :naive_datetime
    field :is_admin, :boolean
    field :is_reviewer, :boolean
    field :is_active, :boolean
    field :bank_account_name, :string
    field :gocardless_name, :string
    field :honorary_member, :boolean
    has_many :attendance, Oas.Trainings.Attendance

    has_one :member_details, Oas.Members.MemberDetails, on_replace: :nilify

    many_to_many :membership_periods, Oas.Members.MembershipPeriod,
      join_through: Oas.Members.Membership

    has_many :memberships, Oas.Members.Membership

    has_many :tokens, Oas.Tokens.Token
    has_many :transactions, Oas.Transactions.Transaction, foreign_key: :who_member_id

    timestamps()
  end

  defp validate_name(changeset) do
    case get_field(changeset, :name) do
      nil ->
        changeset

      name ->
        name = String.downcase(name)

        config =
          from(
            c in Oas.Config.Config,
            limit: 1
          )
          |> Oas.Repo.one!()

        count =
          from(m in Oas.Members.Member,
            where: fragment("lower(?)", m.name) == ^name,
            select: count(m.id)
          )
          |> Oas.Repo.one!()

        case count do
          0 ->
            changeset

          _ ->
            changeset
            |> add_error(
              :name,
              "Name already exists, don't fill this form in again, please contact " <>
                (config.name || "support")
            )
        end
    end
  end

  @doc """
  A member changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def registration_changeset(member, attrs, opts \\ []) do
    member
    |> cast(attrs, [
      :email,
      :password,
      :name,
      :is_active,
      :is_admin,
      :is_reviewer,
      :bank_account_name,
      :gocardless_name
    ])
    |> validate_required([:name])
    |> validate_name()
    |> validate_email()
    |> validate_password(opts)
  end

  def changeset(member, attrs, _opts \\ []) do
    member
    |> cast(attrs, [
      :email,
      :name,
      :is_active,
      :is_admin,
      :is_reviewer,
      :honorary_member,
      :bank_account_name,
      :gocardless_name
    ])
    |> validate_required([:name])
    |> validate_email()
    |> unique_constraint(:gocardless_name)
    |> unique_constraint(:bank_account_name)
  end

  def validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, Oas.Repo)
    |> unique_constraint(:email)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  A member changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(member, attrs) do
    member
    |> cast(attrs, [:email])
    |> validate_email()
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A member changeset for changing the password.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(member, attrs, opts \\ []) do
    member
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(member) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(member, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no member or the member doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Oas.Members.Member{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end
end
