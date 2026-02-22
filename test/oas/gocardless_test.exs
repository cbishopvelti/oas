defmodule Oas.GocardlessTest do
  use ExUnit.Case
  use Oas.DataCase
  import Mock

  describe "gocardless trans_server" do
    # mix test --only only
    # @tag only: true # DEBUG ONLY
    test "Test trans_server iterator" do
      # IO.inspect(Process.whereis(Oas.Gocardless.TransServer) |> Process.alive?(), label: "001")
      with_mock Oas.Gocardless.Transactions,
        process_transacitons: fn ->
          {:ok,
           [
             {"http_x_ratelimit_account_success_remaining", "0"},
             {"http_x_ratelimit_account_success_reset", "1"}
           ]}
        end do
        Oas.Repo.get!(Oas.Config.Config, 1)
        |> Ecto.Changeset.cast(
          %{
            gocardless_id: "***REMOVED***",
            gocardless_key: "***REMOVED***",
            gocardless_account_id: "***REMOVED***"
          },
          [:gocardless_id, :gocardless_key, :gocardless_account_id]
        )
        |> Oas.Repo.update!()

        Oas.Gocardless.Supervisor.restart()

        :timer.sleep(1_500)
        assert_called_exactly(Oas.Gocardless.Transactions.process_transacitons(), 2)
      end
    end
  end
end
