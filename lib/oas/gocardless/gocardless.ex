import Ecto.Query, only: [from: 2]

defmodule Oas.Gocardless do
  defp get_access_token(config) do
    req_body =
      <<"{\"secret_id\":\"#{config.gocardless_id}\", \"secret_key\":\"#{config.gocardless_key}\"}">>

    {:ok, status, _headers, client} =
      :hackney.request(
        :post,
        "https://bankaccountdata.gocardless.com/api/v2/token/new/",
        [
          {<<"accept">>, <<"application/json">>},
          {<<"Content-Type">>, <<"application/json">>}
        ],
        req_body
      )

    {:ok, response_string} = :hackney.body(client)

    if status != 200 do
      raise "Error: #{status} #{response_string}"
    end

    {:ok,
     %{
       "access" => access_token,
       "access_expires" => access_expires,
       "refresh" => refresh_token,
       "refresh_expires" => refresh_expires
     }} = JSON.decode(response_string)

    %{
      access_token: access_token,
      access_expires: access_expires,
      refresh_token: refresh_token,
      refresh_expires: refresh_expires
    }
  end

  # Oas.Gocardless.get_access_token
  def get_access_token do
    config = from(cc in Oas.Config.Config, select: cc) |> Oas.Repo.one()

    if config.gocardless_id == nil || config.gocardless_key == nil do
      {:noconfig}
    else
      {:ok, get_access_token(config)}
    end
  end

  def refresh_access_token(%{refresh_token: refresh_token}) do
    req_body = <<"{\"refresh\":\"#{refresh_token}\"}">>

    {:ok, 200, _headers, client} =
      :hackney.request(
        :post,
        "https://bankaccountdata.gocardless.com/api/v2/token/refresh/",
        [
          {<<"accept">>, <<"application/json">>},
          {<<"Content-Type">>, <<"application/json">>}
        ],
        req_body
      )

    {:ok, response_string} = :hackney.body(client)

    {:ok,
     %{
       "access" => access_token,
       "access_expires" => access_expires
     }} = JSON.decode(response_string)

    %{
      access_token: access_token,
      access_expires: access_expires
    }
  end

  def get_headers(access_token) do
    [
      {<<"accept">>, <<"application/json">>},
      {<<"Content-Type">>, <<"application/json">>},
      {<<"Authorization">>, <<"Bearer #{access_token}">>}
    ]
  end

  def get_banks() do
    {:ok, access_token} = GenServer.call(Oas.Gocardless.AuthServer, :get_access_token)

    {:ok, 200, _headers, client} =
      :hackney.request(
        :get,
        "https://bankaccountdata.gocardless.com/api/v2/institutions/?country=gb",
        get_headers(access_token)
      )

    {:ok, response_string} = :hackney.body(client)
    {:ok, data} = JSON.decode(response_string)
    data
  end

  def get_requisitions(%{access_token: access_token}, %{institution_id: institution_id}) do
    url = "#{Application.fetch_env!(:oas, :app_url)}/config/gocardless/requisition"

    req_data =
      <<"{\"redirect\": \"#{url}\", \"institution_id\": \"#{institution_id}\", \"user_language\":\"EN\" }">>

    {:ok, _, _headers, client} =
      :hackney.request(
        :post,
        "https://bankaccountdata.gocardless.com/api/v2/requisitions/",
        get_headers(access_token),
        req_data
      )

    {:ok, response_string} = :hackney.body(client)
    {:ok, data} = JSON.decode(response_string)

    data
  end

  # Oas.Gocardless.get_accounts()
  def get_accounts() do
    with pid when pid != nil <- Process.whereis(Oas.Gocardless.AuthServer),
         {:ok, access_token} <- GenServer.call(Oas.Gocardless.AuthServer, :get_access_token),
         requisition_id <-
           from(cc in Oas.Config.Config, select: cc.gocardless_requisition_id) |> Oas.Repo.one(),
         {:ok, 200, _headers, client} <-
           :hackney.request(
             :get,
             "https://bankaccountdata.gocardless.com/api/v2/requisitions/#{requisition_id}/",
             get_headers(access_token)
           ) do
      {:ok, response_string} = :hackney.body(client)
      {:ok, data} = JSON.decode(response_string)

      data["accounts"]
    else
      {:ok, status, _headers, client} ->
        {:ok, response_string} = :hackney.body(client)
        {:ok, data} = JSON.decode(response_string)

        send_warning(
          :gocardless_get_accounts,
          "Gocardless, #{status}, #{data |> Map.get("summary", "¯\_(ツ)_/¯")}"
        )

        []

      {:error, :no_access_token} ->
        []

      nil ->
        []
    end
  end

  def get_accounts(_) do
    []
  end

  def send_warning(key, warning) do
    :ets.insert(:global_warnings, {key, warning})
    items = :ets.tab2list(:global_warnings)

    Absinthe.Subscription.publish(
      OasWeb.Endpoint,
      items
      |> Enum.map(fn {key, warning} ->
        %{
          key: key,
          warning: warning
        }
      end),
      global_warnings: "*"
    )
  end

  def delete_warning(key) do
    :ets.delete(:global_warnings, key)

    items =
      :ets.tab2list(:global_warnings)
      |> Enum.map(fn {key, warning} ->
        %{
          key: key,
          warning: warning
        }
      end)

    Absinthe.Subscription.publish(OasWeb.Endpoint, items, global_warnings: "*")
  end

  # Oas.Gocardless.delete_requisitions()
  def delete_requisitions() do
    {:ok, access_token} = GenServer.call(Oas.Gocardless.AuthServer, :get_access_token)

    requisition_id =
      from(cc in Oas.Config.Config, select: cc.gocardless_requisition_id) |> Oas.Repo.one()

    {:ok, 200, _headers, client} =
      :hackney.request(
        :delete,
        "https://bankaccountdata.gocardless.com/api/v2/requisitions/#{requisition_id}/",
        get_headers(access_token)
      )

    {:ok, response_string} = :hackney.body(client)
    {:ok, data} = JSON.decode(response_string)
    {:ok, data}
  end
end
