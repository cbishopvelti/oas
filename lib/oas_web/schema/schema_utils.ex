defmodule OasWeb.Schema.SchemaUtils do

  def handle_error(result) do
    case result do
      {:error, %{errors: errors}} -> 
        outError = errors |> Enum.map(fn {key, {value, _}} -> Atom.to_string(key) <> ": " <> value end)
        {:error, outError}
      x -> x
    end
  end
end