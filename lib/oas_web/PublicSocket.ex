
defmodule OasWeb.PublicSocket do
  use Phoenix.Socket

  channel "llm:*", OasWeb.Channels.LlmChannel
  channel "history", OasWeb.Channels.LlmHistoryChannel
  channel "global", OasWeb.Channels.LlmGlobalChannel

  # @session_options Module.get_attribute(OasWeb.Endpoint, :session_options)

  def connect(params, socket) do
    secret_key_base = Application.get_env(:oas, OasWeb.Endpoint)[:secret_key_base]
    signing_salt = OasWeb.Endpoint.signing_salt()

    opts =
      Plug.Session.COOKIE.init([
        secret_key_base: secret_key_base,
        signing_salt: signing_salt
      ])

    out = case Map.has_key?(params, "cookie") and
      Plug.Session.COOKIE.get(%{
        secret_key_base: secret_key_base
      }, params["cookie"], opts) |> elem(1) |> Map.has_key?("member_token")
    do
      true ->
        {:term, %{
          "member_token" => member_token
        }} = Plug.Session.COOKIE.get(%{
          secret_key_base: secret_key_base
        }, params["cookie"], opts)

        member = member_token && Oas.Members.get_member_by_session_token(member_token)

        out = Phoenix.Socket.assign(socket, :current_member, member)
        out
      false ->
        socket
    end


    {:ok, out}
  end

  def id(_socket), do: nil
end
