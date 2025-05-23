defmodule Oas.GocardlessTest do
  use ExUnit.Case
  use Oas.DataCase
  import Mock

  describe "gocardless trans_server" do

    # mix test --only only
    # @tag only: true # DEBUG ONLY
    test "Test trans_server iterator" do

      # IO.inspect(Process.whereis(Oas.Gocardless.TransServer) |> Process.alive?(), label: "001")
      with_mock Oas.Gocardless.Transactions, [process_transacitons: fn() ->
        {:ok, [
          {"http_x_ratelimit_account_success_remaining", "0"},
          {"http_x_ratelimit_account_success_reset", "1"}
        ]}
      end] do

        Oas.Repo.get!(Oas.Config.Config, 1)
        |> Ecto.Changeset.cast( %{
          gocardless_id: "44e0cb93-04fb-4ca3-ba27-44c198c32b7d",
          gocardless_key: "05dec8633321fd9650143096f293f4099ac44fc2de2c522c0b2dd9efc36e1641c6048d551fec20f3fb5bce0a0ed8a699ce453195e7a8e9c14c453d04b04322e7",
          gocardless_account_id: "3f63f979-11d0-47a1-ace0-894eb8269452"
        }, [:gocardless_id, :gocardless_key, :gocardless_account_id])
        |> Oas.Repo.update!();

        Oas.Gocardless.Supervisor.restart()

        :timer.sleep(1_500)
        assert_called_exactly(Oas.Gocardless.Transactions.process_transacitons(), 2)
      end
    end
  end
end
