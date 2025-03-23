defmodule Oas.Trainings.MyDuration do
  use Ecto.Type
  def type, do: :my_duration

  def cast(%Duration{} = duration) do
    IO.inspect(duration, label: "106")
    {:ok, duration}
  end
  def cast(_), do: :error

  def load(data) when is_binary(data) do
    {:ok, Duration.from_iso8601!(data)}
  end

  # https://hexdocs.pm/ecto/Ecto.Type.html#callbacks
  def dump(%Duration{} = duration) do
    {:ok, Duration.to_iso8601(duration)}
  end
  def dump(_), do: :error
end
