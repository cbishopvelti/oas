defmodule Oas.Members do
  @moduledoc """
  The Members context.
  """

  import Ecto.Query, warn: false
  alias Oas.Repo

  alias Oas.Members.{Member, MemberToken, MemberNotifier}

  ## Database getters

  @doc """
  Gets a member by email.

  ## Examples

      iex> get_member_by_email("foo@example.com")
      %Member{}

      iex> get_member_by_email("unknown@example.com")
      nil

  """
  def get_member_by_email(email) when is_binary(email) do
    Repo.get_by(Member, email: email)
  end

  @doc """
  Gets a member by email and password.

  ## Examples

      iex> get_member_by_email_and_password("foo@example.com", "correct_password")
      %Member{}

      iex> get_member_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_member_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    member = Repo.get_by(Member, email: email)
    if Member.valid_password?(member, password), do: member
  end

  @doc """
  Gets a single member.

  Raises `Ecto.NoResultsError` if the Member does not exist.

  ## Examples

      iex> get_member!(123)
      %Member{}

      iex> get_member!(456)
      ** (Ecto.NoResultsError)

  """
  def get_member!(id), do: Repo.get!(Member, id)

  ## Member registration

  @doc """
  Registers a member.

  ## Examples

      iex> register_member(%{field: value})
      {:ok, %Member{}}

      iex> register_member(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_member(attrs) do
    %Member{}
    |> Member.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking member changes.

  ## Examples

      iex> change_member_registration(member)
      %Ecto.Changeset{data: %Member{}}

  """
  def change_member_registration(%Member{} = member, attrs \\ %{}) do
    Member.registration_changeset(member, attrs, hash_password: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the member email.

  ## Examples

      iex> change_member_email(member)
      %Ecto.Changeset{data: %Member{}}

  """
  def change_member_email(member, attrs \\ %{}) do
    Member.email_changeset(member, attrs)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_member_email(member, "valid password", %{email: ...})
      {:ok, %Member{}}

      iex> apply_member_email(member, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_member_email(member, password, attrs) do
    member
    |> Member.email_changeset(attrs)
    |> Member.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the member email using the given token.

  If the token matches, the member email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_member_email(member, token) do
    context = "change:#{member.email}"

    with {:ok, query} <- MemberToken.verify_change_email_token_query(token, context),
         %MemberToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(member_email_multi(member, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp member_email_multi(member, email, context) do
    changeset =
      member
      |> Member.email_changeset(%{email: email})
      |> Member.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:member, changeset)
    |> Ecto.Multi.delete_all(:tokens, MemberToken.member_and_contexts_query(member, [context]))
  end

  @doc """
  Delivers the update email instructions to the given member.

  ## Examples

      iex> deliver_update_email_instructions(member, current_email, &Routes.member_update_email_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_update_email_instructions(%Member{} = member, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, member_token} = MemberToken.build_email_token(member, "change:#{current_email}")

    Repo.insert!(member_token)
    MemberNotifier.deliver_update_email_instructions(member, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the member password.

  ## Examples

      iex> change_member_password(member)
      %Ecto.Changeset{data: %Member{}}

  """
  def change_member_password(member, attrs \\ %{}) do
    Member.password_changeset(member, attrs, hash_password: false)
  end

  @doc """
  Updates the member password.

  ## Examples

      iex> update_member_password(member, "valid password", %{password: ...})
      {:ok, %Member{}}

      iex> update_member_password(member, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_member_password(member, password, attrs) do
    changeset =
      member
      |> Member.password_changeset(attrs)
      |> Member.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:member, changeset)
    |> Ecto.Multi.delete_all(:tokens, MemberToken.member_and_contexts_query(member, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{member: member}} -> {:ok, member}
      {:error, :member, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_member_session_token(member) do
    {token, member_token} = MemberToken.build_session_token(member)
    Repo.insert!(member_token)
    token
  end

  @doc """
  Gets the member with the given signed token.
  """
  def get_member_by_session_token(token) do
    {:ok, query} = MemberToken.verify_session_token_query(token)
    result = Repo.one(query)
    result
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_session_token(token) do
    Repo.delete_all(MemberToken.token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc """
  Delivers the confirmation email instructions to the given member.

  ## Examples

      iex> deliver_member_confirmation_instructions(member, &Routes.member_confirmation_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_member_confirmation_instructions(confirmed_member, &Routes.member_confirmation_url(conn, :edit, &1))
      {:error, :already_confirmed}

  """
  def deliver_member_confirmation_instructions(%Member{} = member, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if member.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, member_token} = MemberToken.build_email_token(member, "confirm")
      Repo.insert!(member_token)
      MemberNotifier.deliver_confirmation_instructions(member, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a member by the given token.

  If the token matches, the member account is marked as confirmed
  and the token is deleted.
  """
  def confirm_member(token) do
    with {:ok, query} <- MemberToken.verify_email_token_query(token, "confirm"),
         %Member{} = member <- Repo.one(query),
         {:ok, %{member: member}} <- Repo.transaction(confirm_member_multi(member)) do
      {:ok, member}
    else
      _ -> :error
    end
  end

  defp confirm_member_multi(member) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:member, Member.confirm_changeset(member))
    |> Ecto.Multi.delete_all(:tokens, MemberToken.member_and_contexts_query(member, ["confirm"]))
  end

  ## Reset password

  @doc """
  Delivers the reset password email to the given member.

  ## Examples

      iex> deliver_member_reset_password_instructions(member, &Routes.member_reset_password_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_member_reset_password_instructions(%Member{} = member, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, member_token} = MemberToken.build_email_token(member, "reset_password")
    Repo.insert!(member_token)
    MemberNotifier.deliver_reset_password_instructions(member, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the member by reset password token.

  ## Examples

      iex> get_member_by_reset_password_token("validtoken")
      %Member{}

      iex> get_member_by_reset_password_token("invalidtoken")
      nil

  """
  def get_member_by_reset_password_token(token) do
    with {:ok, query} <- MemberToken.verify_email_token_query(token, "reset_password"),
         %Member{} = member <- Repo.one(query) do
      member
    else
      _ -> nil
    end
  end

  @doc """
  Resets the member password.

  ## Examples

      iex> reset_member_password(member, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %Member{}}

      iex> reset_member_password(member, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_member_password(member, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:member, Member.password_changeset(member, attrs))
    |> Ecto.Multi.delete_all(:tokens, MemberToken.member_and_contexts_query(member, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{member: member}} -> {:ok, member}
      {:error, :member, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Moves every attendance of member `from_id` to member `to_id`.

  USE WITH CARE. Run from the console, e.g.
  `Oas.Members.merge_members!(106, 111)`. Credit from payments is not moved.

  Each attendance is deleted from `from_id` and re-added to `to_id`, so its
  charge moves with it. A training both members attended is only removed from
  `from_id`: `to_id` keeps the attendance they already have.

  Memberships move too: a membership of `from_id`, with its fee or the
  transaction that paid it, is handed to `to_id` rather than `to_id` being
  charged again. Where `to_id` already has a membership for that period,
  `from_id` keeps theirs.

  `to_id` gets no warning emails for the moved attendances.

  All or nothing: everything runs inside one outer transaction. If any step
  fails (for example a pricing rule or a credit write fails), everything is
  rolled back, both members are left unchanged, and this raises.

  Returns the list of re-added attendance results on success.

  ## Options

    * `:inserted_by_member_id` - who the re-added attendances are recorded as
      added by. Defaults to 1.
  """
  def merge_members!(from_id, to_id, opts \\ []) do
    inserted_by_member_id = Keyword.get(opts, :inserted_by_member_id, 1)

    if from_id == to_id do
      raise ArgumentError, "merge_members! needs two different members, got #{from_id} twice"
    end

    result =
      # Bookings and undos inside hold their emails and live updates until this commits
      Oas.AfterCommit.transact(fn ->
        # First, so re-adding an attendance finds the target already a member
        # and doesn't charge a second fee.
        merge_move_memberships(from_id, to_id)

        already_attending =
          Ecto.Query.from(a in Oas.Trainings.Attendance,
            where: a.member_id == ^to_id,
            select: a.training_id
          )
          |> Repo.all()
          |> MapSet.new()

        Ecto.Query.from(t in Oas.Trainings.Training,
          join: a in assoc(t, :attendance),
          join: m in assoc(a, :member),
          where: m.id == ^from_id,
          order_by: [asc: t.when, asc: t.id, asc: a.id],
          select: {t, a}
        )
        |> Repo.all()
        |> Enum.reduce_while({:ok, []}, fn {training, attendance}, {:ok, moved} ->
          with {:ok, _} <- Oas.Attendance.delete_attendance(%{attendance_id: attendance.id}),
               {:ok, added} <-
                 merge_add_attendance(to_id, training.id, inserted_by_member_id, already_attending) do
            {:cont, {:ok, List.wrap(added) ++ moved}}
          else
            {:error, reason} -> {:halt, {:error, {:training_id, training.id, reason}}}
          end
        end)
      end)

    case result do
      {:ok, moved} ->
        Enum.reverse(moved)

      {:error, reason} ->
        raise "merge_members! #{from_id} -> #{to_id} rolled back, nothing was changed: " <>
                inspect(reason)
    end
  end

  # Hands the source's memberships to the target, except for periods the target
  # already has one in (a member can only have one membership per period). A
  # membership's fee credit moves with it. A membership left behind is removed,
  # and its fee refunded, when the source's bookings in that period are undone.
  defp merge_move_memberships(from_id, to_id) do
    target_period_ids =
      Ecto.Query.from(m in Oas.Members.Membership,
        where: m.member_id == ^to_id,
        select: m.membership_period_id
      )

    membership_ids =
      Ecto.Query.from(m in Oas.Members.Membership,
        where: m.member_id == ^from_id and m.membership_period_id not in subquery(target_period_ids),
        select: m.id
      )
      |> Repo.all()

    Ecto.Query.from(m in Oas.Members.Membership, where: m.id in ^membership_ids)
    |> Repo.update_all(set: [member_id: to_id])

    Ecto.Query.from(c in Oas.Credits.Credit, where: c.membership_id in ^membership_ids)
    |> Repo.update_all(set: [who_member_id: to_id])

    :ok
  end

  # add_attendance throws its error instead of returning it, so turn the throw
  # back into an error tuple for the outer transaction to roll back on.
  # Returns {:ok, nil} when the target already attends the training.
  defp merge_add_attendance(member_id, training_id, inserted_by_member_id, already_attending) do
    if MapSet.member?(already_attending, training_id) do
      {:ok, nil}
    else
      Oas.Attendance.add_attendance(
        %{member_id: member_id, training_id: training_id},
        %{inserted_by_member_id: inserted_by_member_id, skip_emails: true}
      )
    end
  catch
    {:error, _} = error -> error
  end
end
