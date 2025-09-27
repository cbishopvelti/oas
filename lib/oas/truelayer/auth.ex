import Ecto.Query, only: [from: 2]

defmodule Oas.Truelayer.Auth do

  def handle_callback(code) do
    config = from(cc in Oas.Truelayer.Config, select: cc) |> Oas.Repo.one

    {:ok, status, _headers, client} = :hackney.request(
      :post,
      "https://auth.truelayer.com/connect/token",
      [{<<"Content-Type">>, "application/x-www-form-urlencoded"}],
      {:form,
        [
          grant_type: "authorization_code",
          client_id: config.client_id,
          client_secret: config.client_secret,
          redirect_uri: Application.get_env(:oas, :app_url) <> "/truelayer/callback",
          code: code
        ]
      }
    )

    {:ok, response_string} = :hackney.body(client)

    %{
      "access_token" => access_token,
      "refresh_token" => refresh_token
    } = JSON.decode!(response_string);

    config
    |> Ecto.Changeset.cast(%{
      access_token: access_token,
      refresh_token: refresh_token
    }, [:access_token, :refresh_token])
    |> Oas.Repo.update()
  end

  # Oas.Truelayer.Auth.refresh_token()
  def refresh_token() do
    config = from(cc in Oas.Truelayer.Config, select: cc) |> Oas.Repo.one

    {:ok, status, _headers, client} = :hackney.request(
      :post,
      "https://auth.truelayer.com/connect/token",
      [{<<"Content-Type">>, "application/x-www-form-urlencoded"}],
      {:form,
        [
          grant_type: "refresh_token",
          client_id: config.client_id,
          client_secret: config.client_secret,
          refresh_token: config.refresh_token
        ]
      }
    )

    {:ok, response_string} = :hackney.body(client)
    IO.inspect(response_string, label: "009 response_string")

    %{
      "access_token" => access_token,
      "refresh_token" => refresh_token
    } = JSON.decode!(response_string);

    config
    |> Ecto.Changeset.cast(%{
      access_token: access_token,
      refresh_token: refresh_token
    }, [:access_token, :refresh_token])
    |> Oas.Repo.update()
  end

  # Oas.Truelayer.Auth.set_account()
  def set_account() do
    config = from(cc in Oas.Truelayer.Config, select: cc) |> Oas.Repo.one

    {:ok, status, _headers, client} = :hackney.request(
      :get,
      "https://api.truelayer.com/data/v1/accounts",
      [{<<"Authorization">>, "Bearer " <> config.access_token}]
    )

    {:ok, response_string} = :hackney.body(client)
    IO.inspect(response_string, label: "010 accounts")

    data = JSON.decode!(response_string)
    accounts = Map.get(data, "results")
    if (length(accounts) > 1) do
      raise "More than 1 account selected"
    end

    account_id = accounts |>  List.first() |> Map.get("account_id")

    config |> Ecto.Changeset.cast(%{
      account_id: account_id
    }, [:account_id])
    |> Oas.Repo.update();


  end

  # Oas.Truelayer.Auth.get_transactions()
  def get_transactions() do
    config = from(cc in Oas.Truelayer.Config, select: cc) |> Oas.Repo.one

    {:ok, status, _headers, client} = :hackney.request(
      :get,
      "https://api.truelayer.com/data/v1/accounts/#{config.account_id}/transactions",
      [{<<"Authorization">>, "Bearer " <> config.access_token},
        {<<"Accept">>, "application/json"},
      ]
    )
    {:ok, response_string} = :hackney.body(client)

    store_transactions(response_string)

    IO.inspect(response_string, label: "011", limit: :infinity)
    data = JSON.decode!(response_string)
    IO.inspect(data, label: "012", limit: :infinity)
  end

  defp store_transactions(data) do
    dir = Application.get_env(:oas, :truelayer_backup_dir, "./data/truelayer_backup")

    when1 = DateTime.utc_now() |> DateTime.to_iso8601()
    path = Path.join(dir, "transactions_" <> when1 <> ".json")

    File.write!(path, data)
  end
end
