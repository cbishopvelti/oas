defimpl Jason.Encoder, for: PID do
  def encode(pid, opts) do
    pid
    |> inspect()
    |> Jason.Encode.string(opts)
  end
end
