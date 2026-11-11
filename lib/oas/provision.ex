defmodule Oas.Provision do
  @moduledoc """
  Sets up a new society's database: the society settings and the first admin.
  Used by `mix oas.provision`, which runs the migrations first.

  Safe to run more than once. Settings that already have the given value are
  left alone, and the admin is only created if no member has that email.
  Nothing is emailed and no password is taken or shown: a new admin gets a
  random password nobody knows and a set-password link, built the same way
  as the reset password email.
  """

  alias Oas.Repo
  alias Oas.Members.{Member, MemberToken}

  @settings_fields [:name, :time_zone, :currency]

  @doc """
  Applies `opts` (a map with `:name`, `:time_zone`, `:currency`,
  `:admin_email`, `:admin_name`).

  Returns `{:ok, report}` where `report` has:
    * `:settings` - the settings fields that changed, as `{field, old, new}`
    * `:admin` - `:created`, `:exists` or `:exists_not_admin`
    * `:admin_email` - the admin's email
    * `:link` - a set-password link, or nil when none was made

  A link is made for a new admin, or for an existing admin when `:new_link`
  is true. Returns `{:error, step, changeset_or_message}` if a value is invalid,
  in which case nothing is saved.
  """
  def run(opts) do
    Repo.transaction(fn ->
      with {:ok, settings} <- update_settings(opts),
           {:ok, admin, member} <- ensure_admin(opts),
           {:ok, link} <- maybe_link(admin, member, opts) do
        %{settings: settings, admin: admin, admin_email: member.email, link: link}
      else
        {:error, step, reason} -> Repo.rollback({step, reason})
      end
    end)
    |> case do
      {:ok, report} -> {:ok, report}
      {:error, {step, reason}} -> {:error, step, reason}
    end
  end

  @doc "True when the report says nothing was changed."
  def unchanged?(%{settings: [], admin: admin, link: nil}) when admin != :created, do: true
  def unchanged?(_), do: false

  defp update_settings(opts) do
    case Oas.Settings.get_config() do
      nil ->
        {:error, :settings, "there is no settings row; are the migrations up to date?"}

      config ->
        attrs = Map.new(@settings_fields, fn f -> {f, Map.fetch!(opts, f)} end)

        changes =
          for f <- @settings_fields,
              Map.get(config, f) != attrs[f],
              do: {f, Map.get(config, f), attrs[f]}

        if changes == [] do
          {:ok, []}
        else
          case Oas.Settings.update_config(attrs, @settings_fields) do
            {:ok, _} -> {:ok, changes}
            {:error, changeset} -> {:error, :settings, changeset}
          end
        end
    end
  end

  defp ensure_admin(opts) do
    email = String.trim(opts.admin_email)

    case Oas.Members.get_member_by_email(email) do
      %Member{is_admin: true} = member ->
        {:ok, :exists, member}

      %Member{} = member ->
        {:ok, :exists_not_admin, member}

      nil ->
        # The password column can't be empty, so like the admin site's "add
        # member" this sets a random one nobody ever sees. The admin replaces
        # it through the set-password link.
        %Member{}
        |> Member.registration_changeset(%{
          email: email,
          name: String.trim(opts.admin_name),
          password: random_password(),
          is_admin: true,
          is_active: true
        })
        |> Repo.insert()
        |> case do
          {:ok, member} -> {:ok, :created, member}
          {:error, changeset} -> {:error, :admin, changeset}
        end
    end
  end

  defp random_password,
    do: :crypto.strong_rand_bytes(32) |> Base.url_encode64() |> binary_part(0, 40)

  defp maybe_link(:created, member, _opts), do: {:ok, set_password_link(member)}
  defp maybe_link(:exists, member, %{new_link: true}), do: {:ok, set_password_link(member)}
  defp maybe_link(_, _member, _opts), do: {:ok, nil}

  # Same token and URL as the reset password email
  # (OasWeb.MemberResetPasswordController.create/2). Valid for one day.
  defp set_password_link(member) do
    {encoded_token, member_token} = MemberToken.build_email_token(member, "reset_password")
    Repo.insert!(member_token)
    OasWeb.Router.Helpers.member_reset_password_url(OasWeb.Endpoint, :edit, encoded_token)
  end
end
