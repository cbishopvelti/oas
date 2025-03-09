defmodule Oas.Gocardless.TransactionsMockData do

  def get_transactions_mock_1(_when) do
    {:ok, [%{
      "bookingDate" => "2025-03-09",
      "bookingDateTime" => "2025-02-07T00:00:00.000Z",
      "debtorName" => "CHRISB",
      "internalTransactionId" => "1bb4606bd800c76abfebffb5a5511db0",
      "proprietaryBankTransactionCode" => "POS",
      "remittanceInformationUnstructured" => "0543 06JAN25      LV INSURANCE W    0330 1239970 GB",
      "transactionAmount" => %{"amount" => "45", "currency" => "GBP"},
      "transactionId" => "8AD4A5144E8D4C5987C0BAC4913DBD6340C9D083424B1AA5F38729B4A81C3C3E82153E637BD4BAA5CD31D80B26B28493"
    }],
    [
      {"Date", "Sun, 16 Feb 2025 11:29:24 GMT"},
      {"Content-Type", "application/json"},
      {"Transfer-Encoding", "chunked"},
      {"Connection", "keep-alive"},
      {"vary", "Accept, Accept-Language, Cookie"},
      {"vary", "Accept-Encoding"},
      {"allow", "GET, HEAD, OPTIONS"},
      {"http_x_ratelimit_limit", "100"},
      {"http_x_ratelimit_remaining", "99"},
      {"http_x_ratelimit_reset", "59"},
      {"http_x_ratelimit_account_success_limit", "4"},
      {"http_x_ratelimit_account_success_remaining", "0"},
      {"http_x_ratelimit_account_success_reset", "86307"},
      {"Cache-Control", "no-store, no-cache, max-age=0"},
      {"x-c-uuid", "07a75933-1cbc-44e2-bd48-98cd61d08edb"},
      {"x-u-uuid", "e6913b9b-0c57-41e2-9d65-0264ffb6c276"},
      {"x-frame-options", "DENY"},
      {"content-language", "en"},
      {"x-content-type-options", "nosniff"},
      {"referrer-policy", "same-origin"},
      {"client-region", "ES"},
      {"cf-ipcountry", "GB"},
      {"strict-transport-security", "max-age=31556926; includeSubDomains;"},
      {"CF-Cache-Status", "BYPASS"},
      {"Server", "cloudflare"},
      {"CF-RAY", "912d33138a2171ec-LHR"}
    ]
    }
  end

  def get_transactions_mock_2(_when) do
    {:ok,
     [
       %{
         "bookingDate" => "2025-02-10",
         "bookingDateTime" => "2025-02-10T00:00:00.000Z",
         "internalTransactionId" => "e884c3b4c18dff7a1a754c3b1de583a1",
         "proprietaryBankTransactionCode" => "DPC",
         "remittanceInformationUnstructured" => "Albany            CHRIS BISHOP      VIA ONLINE - PYMT FP 10/02/25 10    03102227707126000N",
         "transactionAmount" => %{"amount" => "-10.00", "currency" => "GBP"},
         "transactionId" => "8AD4A5144E8D4C5987C0BAC4913DBD637C1183938B7FDEEC31BD3280DF58208B6F66AD4CDA4DBFDAEC4CD17574883600"
       },
       %{
         "bookingDate" => "2025-02-07",
         "bookingDateTime" => "2025-02-07T00:00:00.000Z",
         "creditorName" => "BENDYSTUDIO PETHERTON ROA GB",
         "internalTransactionId" => "d2c60efbb654d12b79f195dd7b79ca56",
         "proprietaryBankTransactionCode" => "POS",
         "remittanceInformationUnstructured" => "0543 06FEB25      BENDYSTUDIO       PETHERTON ROA GB",
         "transactionAmount" => %{"amount" => "-6.06", "currency" => "GBP"},
         "transactionId" => "8AD4A5144E8D4C5987C0BAC4913DBD63C64DD72D01B64EC0CDCD3879F56D2B0DFF3D22B59685E453B66353FBBA6D0E38"
       },
       %{
         "bookingDate" => "2025-02-07",
         "bookingDateTime" => "2025-02-07T00:00:00.000Z",
         "debtorName" => "CAROL BISHOP MORTGAGELOAN",
         "internalTransactionId" => "7b3ed063593ab62799ee9e4dfd982f27",
         "proprietaryBankTransactionCode" => "BAC",
         "remittanceInformationUnstructured" => "CAROL BISHOP      MORTGAGELOAN      FP 07/02/25 1232  00155663632BHWCSBB",
         "transactionAmount" => %{"amount" => "9500.00", "currency" => "GBP"},
         "transactionId" => "8AD4A5144E8D4C5987C0BAC4913DBD63C64DD72D01B64EC0CDCD3879F56D2B0DA83C63321000FFFC5D59FCD6A5CA3D11"
       },
       %{
         "bookingDate" => "2025-02-06",
         "bookingDateTime" => "2025-02-06T00:00:00.000Z",
         "debtorName" => "CAROL BISHOP MORTGAGELOAN",
         "internalTransactionId" => "ee613936ee500996af38ae3798c35992",
         "proprietaryBankTransactionCode" => "BAC",
         "remittanceInformationUnstructured" => "CAROL BISHOP      MORTGAGELOAN      FP 06/02/25 1245  00155663632BHWCCLC",
         "transactionAmount" => %{"amount" => "10000.00", "currency" => "GBP"},
         "transactionId" => "8AD4A5144E8D4C5987C0BAC4913DBD635F559F563AED0C5F56331D61D0541E76FBAB5EA3760DE90525CF86CD078B0F4E"
       },
       %{
         "bookingDate" => "2025-02-05",
         "bookingDateTime" => "2025-02-05T00:00:00.000Z",
         "internalTransactionId" => "07259d996d46e5b956c38349f64ff85b",
         "proprietaryBankTransactionCode" => "D/D",
         "remittanceInformationUnstructured" => "SANTANDER MORTGAGE",
         "transactionAmount" => %{"amount" => "-701.98", "currency" => "GBP"},
         "transactionId" => "8AD4A5144E8D4C5987C0BAC4913DBD63341720D80F633C6D3F34971EF9BD0AA733D95BA898E2398248B4784166F5598E"
       },
       %{
         "bookingDate" => "2025-02-05",
         "bookingDateTime" => "2025-02-05T00:00:00.000Z",
         "creditorName" => "GOOGLE ONE LONDON GB",
         "internalTransactionId" => "46755067d4d9dc04c812a409eac9adc4",
         "proprietaryBankTransactionCode" => "POS",
         "remittanceInformationUnstructured" => "0543 05FEB25      GOOGLE ONE        LONDON GB",
         "transactionAmount" => %{"amount" => "-7.99", "currency" => "GBP"},
         "transactionId" => "8AD4A5144E8D4C5987C0BAC4913DBD63341720D80F633C6D3F34971EF9BD0AA7A5430486BED4BA8FA26A416C484A00BF"
       }
     ]}
  end
end
