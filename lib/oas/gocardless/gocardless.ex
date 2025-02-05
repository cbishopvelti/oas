import Ecto.Query, only: [from: 2]

defmodule Oas.Gocardless do

  defp get_access_token(config) do
    req_body = <<"{\"secret_id\":\"#{config.gocardless_id}\", \"secret_key\":\"#{config.gocardless_key}\"}">>

    {:ok, status, _headers, client} = :hackney.request(
      :post, "https://bankaccountdata.gocardless.com/api/v2/token/new/", [
        {<<"accept">>, <<"application/json">>},
        {<<"Content-Type">>, <<"application/json">>}
      ],
      req_body
    )

    {:ok, response_string} = :hackney.body(client)
    if status != 200 do
      IO.inspect(response_string)
      raise "Error: #{status} #{response_string}"
    end

    {:ok, %{
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
    config = from(cc in Oas.Config.Config, select: cc) |> Oas.Repo.one

    if (config.gocardless_id == nil || config.gocardless_key == nil) do
      {:noconfig}
    else
      {:ok, get_access_token(config)}
    end


  end

  def refresh_access_token(%{refresh_token: refresh_token}) do
    req_body = <<"{\"refresh\":\"#{refresh_token}\"}">>

    {:ok, 200, _headers, client} = :hackney.request(
      :post, "https://bankaccountdata.gocardless.com/api/v2/token/refresh/", [
        {<<"accept">>, <<"application/json">>},
        {<<"Content-Type">>, <<"application/json">>}
      ],
      req_body
    )

    {:ok, response_string} = :hackney.body(client)
    {:ok, %{
      "access" => access_token,
      "access_expires" => access_expires
    }} = JSON.decode(response_string)

    %{
      access_token: access_token,
      access_expires: access_expires,
    }
  end

  defp get_headers(access_token) do
    [
      {<<"accept">>, <<"application/json">>},
      {<<"Content-Type">>, <<"application/json">>},
      {<<"Authorization">>, <<"Bearer #{access_token}">>}
    ]
  end

  def get_banks(%{access_token: access_token}) do

    {:ok, 200, _headers, client} = :hackney.request(:get, "https://bankaccountdata.gocardless.com/api/v2/institutions/?country=gb",
      get_headers(access_token)
    )
    {:ok, response_string} = :hackney.body(client)
    {:ok, data} = JSON.decode(response_string)
    data
  end

  def get_requisitions(%{access_token: access_token}, %{institution_id: institution_id}) do
    url = "#{Application.fetch_env!(:oas, :app_url)}/config/gocardless/requisition"

    req_data = <<"{\"redirect\": \"#{url}\", \"institution_id\": \"#{institution_id}\", \"user_language\":\"EN\" }">>

    {:ok, _, _headers, client} = :hackney.request(:post, "https://bankaccountdata.gocardless.com/api/v2/requisitions/",
      get_headers(access_token),
      req_data
    )
    {:ok, response_string} = :hackney.body(client)
    {:ok, data} = JSON.decode(response_string)

    data
  end

  def get_accounts(%{access_token: access_token, requisition_id: requisition_id}) do
    {:ok, 200, _headers, client} = :hackney.request(
      :get, "https://bankaccountdata.gocardless.com/api/v2/requisitions/#{requisition_id}/",
        get_headers(access_token)
    )
    {:ok, response_string} = :hackney.body(client)
    {:ok, data} = JSON.decode(response_string)

    data["accounts"]
  end
  def get_accounts(_) do
    []
  end

  def get_transactions(%{access_token: access_token}) do
    # id = "ab1c7c82-5edc-4bfc-9901-be55704adc80"
    id = "AF4B5D2A5539FA49055ECF82EBCEDFFA"

    # GB48NWBK60052420591675

    {:ok, 200, _headers, client} = :hackney.request(
      :get, "https://bankaccountdata.gocardless.com/api/v2/accounts/#{id}/transactions/", [
        {<<"accept">>, <<"application/json">>},
        {<<"Content-Type">>, <<"application/json">>},
        {<<"Authorization">>, <<"Bearer #{access_token}">>}
      ]
    )
    {:ok, response_string} = :hackney.body(client)
    {:ok, data} = JSON.decode(response_string)

    IO.inspect(data, label: "004")
  end
end
