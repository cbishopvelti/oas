defmodule Oas.Pricing.CalcAttendanceTest do
  use ExUnit.Case, async: true

  alias Oas.Pricing.CalcAttendance

  describe "lua_result_to_decimal/1" do
    test "converts a float result from a Lua script" do
      {[result], _} =
        Lua.new()
        |> Lua.set!([:trainings], [10.0, 5.5])
        |> Lua.eval!("return trainings[1] + trainings[2]")

      assert is_float(result)
      assert Decimal.eq?(CalcAttendance.lua_result_to_decimal(result), Decimal.new("15.5"))
    end

    test "converts an integer result" do
      {[result], _} = Lua.new() |> Lua.eval!("return 12")
      assert Decimal.eq?(CalcAttendance.lua_result_to_decimal(result), Decimal.new("12"))
    end

    test "converts a numeric string and passes a Decimal through" do
      assert Decimal.eq?(CalcAttendance.lua_result_to_decimal("7.25"), Decimal.new("7.25"))
      assert Decimal.eq?(CalcAttendance.lua_result_to_decimal(Decimal.new("3")), Decimal.new("3"))
    end

    test "does not lose precision from binary floats" do
      amount = CalcAttendance.lua_result_to_decimal(0.1 + 0.2) |> Decimal.round(2, :down)
      assert Decimal.eq?(amount, Decimal.new("0.30"))
    end

    test "raises a clear error for a non numeric result" do
      assert_raise ArgumentError, ~r/must return a number/, fn ->
        CalcAttendance.lua_result_to_decimal(nil)
      end
    end
  end

  describe "to_debit_amount/1" do
    test "negates a positive price" do
      assert Decimal.eq?(CalcAttendance.to_debit_amount(Decimal.new("4.50")), Decimal.new("-4.50"))
    end

    test "allows a zero price" do
      assert Decimal.eq?(CalcAttendance.to_debit_amount(Decimal.new("0")), Decimal.new("0"))
    end

    test "rejects a negative price" do
      assert_raise ArgumentError, fn -> CalcAttendance.to_debit_amount(Decimal.new("-1")) end
    end
  end
end
