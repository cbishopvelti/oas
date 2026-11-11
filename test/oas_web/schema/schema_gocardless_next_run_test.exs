defmodule OasWeb.Schema.SchemaGocardlessNextRunTest do
  use ExUnit.Case, async: true

  alias OasWeb.Schema.SchemaGocardless

  test "next_run is the scheduled instant as an ISO 8601 UTC datetime" do
    now = ~U[2026-11-11 23:30:15.123456Z]

    # 10 hours later crosses midnight, so the date must move on too.
    assert SchemaGocardless.next_run(10 * 60 * 60 * 1000, now) == "2026-11-12T09:30:15Z"
  end

  test "next_run is nil when nothing is scheduled" do
    assert SchemaGocardless.next_run(nil) == nil
    # Process.read_timer/1 returns false once the timer has fired.
    assert SchemaGocardless.next_run(false) == nil
  end
end
