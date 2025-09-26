defmodule Oas.Plaid.Link do

  defp plaid_client_id, do: "68d33dff1196ee00232d8689"
  defp plaid_secret, do: "485be5ffc0860615caf2262aaf45f4"


  # Oas.Plaid.Link.get_link()
  def get_link_token do

    data_to_send = %{
      client_name: "Christopher Bishop",
      client_id: plaid_client_id(),
      secret: plaid_secret(),
      language: "en",
      products: ["transactions"],
      country_codes: ["GB"],
      user: %{
        client_user_id: "1"
      },
      redirect_uri: "http://localhost:3999/plaid/success"
    }

    data_to_send = JSON.encode_to_iodata!(data_to_send)

    {:ok, _status, _headers, client} = :hackney.request(
      :post,
      "https://sandbox.plaid.com/link/token/create",
      [
        {<<"Content-Type">>, "application/json"}
      ],
      data_to_send
    )

    {:ok, response_string} = :hackney.body(client)

    response = JSON.decode!(response_string)
    link_token = Map.get(response, "link_token")
    IO.inspect(link_token, label: "003");

    {:ok, Map.get(response, "link_token")}
  end

  def exchange (public_token) do

    data_to_send = JSON.encode_to_iodata!(%{
      client_id: plaid_client_id(),
      secret: plaid_secret(),
      public_token: public_token
    })

    {:ok, _status, _headres, client} = :hackney.request(
      :post,
      "https://sandbox.plaid.com/item/public_token/exchange",
      [{<<"Content-Type">>, "application/json"}],
      data_to_send
    )

    {:ok, response_string} = :hackney.body(client);
    IO.inspect(response_string, label: "009");

    response = JSON.decode!(response_string)

  end
end
