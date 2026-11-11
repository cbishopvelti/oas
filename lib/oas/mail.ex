defmodule Oas.Mail do
  @moduledoc """
  The one place that builds and sends email.

  Sender:

    * The From address is the one in the `Oas.TokenMailer` `:from` config
      (MAIL_FROM_ADDRESS in runtime.exs, or the config file).
    * The From name is the society name from the settings
      (`Oas.Settings.society_name/0`), unless MAIL_FROM_NAME is set, in which
      case that wins (runtime.exs puts it in `:oas, :mail_from_name`).
    * Reply-To is the society's contact email from the settings, when set.

  Options:

    * `:mailer` - the Swoosh mailer to send through. Defaults to `Oas.Mailer`.
      Token mail goes through `Oas.TokenMailer`, which has its own config.
    * `:attachments` - a list of attachments, each anything that
      `Swoosh.Email.attachment/2` accepts (a path or a `Swoosh.Attachment`).

  Returns `{:ok, email}` when the mailer accepts it, otherwise the mailer's
  error.
  """

  import Swoosh.Email

  def deliver(recipient, subject, body, opts \\ []) do
    mailer = Keyword.get(opts, :mailer, Oas.Mailer)

    email =
      new()
      |> to(recipient)
      |> from(sender())
      |> put_reply_to()
      |> subject(subject)
      |> text_body(body)

    email =
      opts
      |> Keyword.get(:attachments, [])
      |> Enum.reduce(email, &attachment(&2, &1))

    with {:ok, _metadata} <- mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc "The `{name, address}` every email is sent from."
  def sender do
    {from_name(), from_address()}
  end

  defp from_name do
    case Application.get_env(:oas, :mail_from_name) do
      name when is_binary(name) and name != "" -> name
      _ -> Oas.Settings.society_name()
    end
  end

  defp from_address do
    case Application.get_env(:oas, Oas.TokenMailer)[:from] do
      {_name, address} -> address
      address -> address
    end
  end

  defp put_reply_to(email) do
    case Oas.Settings.get_config_value(:contact_email) do
      address when is_binary(address) ->
        case String.trim(address) do
          "" -> email
          trimmed -> reply_to(email, trimmed)
        end

      _ ->
        email
    end
  end
end
