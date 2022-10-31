defmodule OasWeb.Schema.SchemaUtils do

  def handle_error(result) do


    case result do
      {:error, %{errors: errors}} -> 
        outError = errors
        |> Enum.map(fn {key, {value, _}} ->
          message = Atom.to_string(key) <> ": " <> value
          %{message: message, db_field: Atom.to_string(key)}
        end)

        {:error, outError}
      x -> x
    end
  end
end