defmodule OasWeb.OriginsTest do
  # Changes application env, so not async.
  use ExUnit.Case, async: false

  alias OasWeb.Origins

  setup do
    keys = [:restrict_origins, :app_url, :public_url, OasWeb.Endpoint]
    saved = for k <- keys, do: {k, Application.fetch_env(:oas, k)}

    on_exit(fn ->
      for {k, v} <- saved do
        case v do
          {:ok, value} -> Application.put_env(:oas, k, value)
          :error -> Application.delete_env(:oas, k)
        end
      end
    end)

    Application.put_env(:oas, :app_url, "https://admin.example.org")
    Application.put_env(:oas, :public_url, "https://www.example.org")

    Application.put_env(
      :oas,
      OasWeb.Endpoint,
      Keyword.put(Application.get_env(:oas, OasWeb.Endpoint, []), :url,
        host: "server.example.org",
        port: 443,
        scheme: "https"
      )
    )

    :ok
  end

  test "allows every origin when not restricted" do
    Application.put_env(:oas, :restrict_origins, false)
    assert Origins.allowed?("https://evil.example.com")
    assert Origins.cors_allowed?(nil, "https://evil.example.com")
  end

  describe "when restricted" do
    setup do
      Application.put_env(:oas, :restrict_origins, true)
      :ok
    end

    test "allows the admin and public apps" do
      assert Origins.cors_allowed?(nil, "https://admin.example.org")
      assert Origins.cors_allowed?(nil, "https://www.example.org")
      assert Origins.socket_allowed?(URI.parse("https://admin.example.org"))
      assert Origins.socket_allowed?(URI.parse("https://WWW.example.org"))
    end

    test "allows the server's own host" do
      assert Origins.socket_allowed?(URI.parse("https://server.example.org"))
    end

    test "rejects other origins" do
      refute Origins.cors_allowed?(nil, "https://evil.example.com")
      refute Origins.cors_allowed?(nil, "http://admin.example.org")
      refute Origins.cors_allowed?(nil, "https://admin.example.org:8443")
      refute Origins.cors_allowed?(nil, "https://admin.example.org.evil.com")
      refute Origins.cors_allowed?(nil, "null")
      refute Origins.socket_allowed?(URI.parse("https://evil.example.com"))
    end

    test "reads app urls at call time" do
      Application.put_env(:oas, :app_url, "https://admin.other.org")
      assert Origins.allowed?("https://admin.other.org")
      refute Origins.allowed?("https://admin.example.org")
    end
  end
end
