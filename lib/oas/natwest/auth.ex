import Ecto.Query, only: [from: 2]

defmodule Oas.Natwest.Auth do

  # Oas.Natwest.Auth.access_token()
  def access_token() do
    config = from(cc in Oas.Natwest.Config, select: cc) |> Oas.Repo.one

    {:ok, _status, _headers, client} = :hackney.request(
      :post,
      "https://ob.sandbox.natwest.com/token",
      [{<<"Content-Type">>, "application/x-www-form-urlencoded"}],
      {:form, [
        grant_type: "client_credentials",
        client_id: config.client_id,
        client_secret: config.client_secret,
        scope: "accounts"
      ]}
    )

    {:ok, data_string} = :hackney.body(client)
    IO.inspect(data_string, label: "201 data_string")
    %{
      "access_token" => access_token,
      "expires_in" => _expries_in
    } = JSON.decode!(data_string)

    # write the access token
    config
    |> Ecto.Changeset.cast(%{
      consent_access_token: access_token,
    }, [:consent_access_token])
    |> Oas.Repo.update()

  end

  # Oas.Natwest.Auth.access_token()
  # Oas.Natwest.Auth.consent()
  def consent() do
    config = from(cc in Oas.Natwest.Config, select: cc) |> Oas.Repo.one

    IO.inspect(config, label: "200")

    {:ok, _status, _headers, client} = :hackney.request(
      :post,
      "https://ob.sandbox.natwest.com/open-banking/v4.0/aisp/account-access-consents",
      [
        {<<"Content-Type">>, "application/json"},
        {<<"Authorization">>, "Bearer " <> config.consent_access_token}
      ],
      JSON.encode_to_iodata!(%{
        "Data" => %{
          "Permissions" => [
            "ReadAccountsDetail",
            "ReadBalances",
            "ReadTransactionsCredits",
            "ReadTransactionsDebits",
            "ReadTransactionsDetail"
          ]
        },
        "Risk" => %{}
      })
    )

    {:ok, data_string} = :hackney.body(client)
    data = JSON.decode!(data_string)

    # link = Kernel.get_in(data, ["Links", "Self"]) |> IO.inspect(label: "105 link")
    consent_id = Kernel.get_in(data, ["Data", "ConsentId"])

    redirect_uri = Application.get_env(:oas, :app_url) <> "/natwest/callback"

    url = "https://api.sandbox.natwest.com/authorize?client_id=#{config.client_id}&response_type=code id_token&scope=openid accounts&redirect_uri=#{redirect_uri}&request=#{consent_id}"

    IO.inspect(url, label: "104 data_string")

    {:ok, url}
  end

  def exchange_code(code) do
    config = from(cc in Oas.Natwest.Config, select: cc) |> Oas.Repo.one

    {:ok, _status, _headers, client} = :hackney.request(
      :post,
      "https://ob.sandbox.natwest.com/token",
      [{<<"Content-Type">>, "application/x-www-form-urlencoded"}],
      {:form, [
        client_id: config.client_id,
        client_secret: config.client_secret,
        grant_type: "authorization_code",
        code: code
      ]}
    )

    {:ok, data_string } = :hackney.body(client)

    %{
      "refresh_token" => refresh_token,
      "access_token" => access_token,
      "id_token" => id_token,
    } = JSON.decode!(data_string)

    config
    |> Ecto.Changeset.cast(%{
      refresh_token: refresh_token,
      access_token: access_token,
      id_token: id_token
    }, [:refresh_token, :access_token, :id_token])
    |> Oas.Repo.update()
  end

  # Oas.Natwest.Auth.set_account()
  def set_account() do
    config = from(cc in Oas.Natwest.Config, select: cc) |> Oas.Repo.one

    {:ok, _s, _h, client} = :hackney.request(
      :get,
      "https://ob.sandbox.natwest.com/open-banking/v4.0/aisp/accounts",
      [{<<"Authorization">>, "Bearer " <> config.access_token}]
    )
    {:ok, data_string} = :hackney.body(client)
    data = JSON.decode!(data_string)
    accounts = Kernel.get_in(data, ["Data", "Account"])
    if length(accounts) != 1 do
      raise "Select one and only one account."
    end

    account_id = accounts |> List.first() |> Map.get("AccountId")

    config
    |> Ecto.Changeset.cast(%{
      account_id: account_id
    }, [:account_id])
    |> Oas.Repo.update()
  end

  # Oas.Natwest.Auth.get_transactions()
  def get_transactions() do
    config = from(cc in Oas.Natwest.Config, select: cc) |> Oas.Repo.one

    {:ok, _s, _h, client} = :hackney.request(
      :get,
      "https://ob.sandbox.natwest.com/open-banking/v4.0/aisp/accounts/#{config.account_id}/transactions",
      [{<<"Authorization">>, "Bearer " <> config.access_token}]
    )

    {:ok, data_string} = :hackney.body(client)
    store_transactions(data_string)

    data = JSON.decode!(data_string)

    IO.inspect(data, label: "009 transactions", limit: :infinity)
  end

  defp store_transactions(data) do
    dir = Application.fetch_env!(:oas, :backup_dir)

    when1 = DateTime.utc_now() |> DateTime.to_iso8601()
    path = Path.join([dir, "natwest_backup", "transactions_" <> when1 <> ".json"])

    File.write!(path, data)
  end

end
