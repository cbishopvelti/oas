defmodule Oas.TokenMailerTest do
  use Oas.DataCase
  alias Oas.TokenMailer

  describe "should_send_warning/1" do
    test("One debit") do
      out = TokenMailer.should_send_warning(Date.from_iso8601!("2025-03-11"), [
        %{
          amount: Decimal.new("-1"),
          when: Date.from_iso8601!("2025-03-12"),
          after_amount: Decimal.new("-1")
        }
      ])
      assert out
    end

    test("Two debit") do
      out = TokenMailer.should_send_warning(Date.from_iso8601!("2025-03-11"), [
        %{
          amount: Decimal.new("-1"),
          when: Date.from_iso8601!("2025-03-13"),
          after_amount: Decimal.new("-1")
        },
        %{
          amount: Decimal.new("-1"),
          when: Date.from_iso8601!("2025-03-12"),
          after_amount: Decimal.new("-1")
        }
      ])
      assert !out
    end
    # @tag only: true
    test("date between") do
      out = TokenMailer.should_send_warning(Date.from_iso8601!("2025-03-13"), [
        %{
          amount: Decimal.new("-1"),
          when: Date.from_iso8601!("2025-03-14"),
          after_amount: Decimal.new("-1")
        },
        %{
          amount: Decimal.new("-1"),
          when: Date.from_iso8601!("2025-03-12"),
          after_amount: Decimal.new("-1")
        }
      ])
      assert out
    end
    # @tag only: true
    test("date on") do
      out = TokenMailer.should_send_warning(Date.from_iso8601!("2025-03-13"), [
        %{
          amount: Decimal.new("-1"),
          when: Date.from_iso8601!("2025-03-14"),
          after_amount: Decimal.new("-1")
        },
        %{
          amount: Decimal.new("-1"),
          when: Date.from_iso8601!("2025-03-13"),
          after_amount: Decimal.new("-1")
        }
      ])
      assert out
    end
  end
end
