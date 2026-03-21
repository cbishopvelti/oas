defmodule Oas.Pricing.CalcAttendance do

  # If not pricing rule, just use the old way
  def calculate(%{pricing_instance: nil} = training, _, _) do
    training_where = training |> Map.get(:training_where) || %{}
    training_where_time = (training_where || %{}) |> Map.get(:training_where_time) |> List.first() || %{}

    (training_where_time |> Map.get(:credit_amount)) ||
    (training_where |> Map.get(:credit_amount)) ||
    Oas.Config.Tokens.get_min_token().value
  end
  def calculate(training, member, %{now: now}) do

  end
end
