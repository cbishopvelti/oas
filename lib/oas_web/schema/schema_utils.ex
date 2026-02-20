defmodule OasWeb.Schema.SchemaUtils do

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, msg ->
      token = "%{#{key}}"

      case String.contains?(msg, token) do
        true  -> String.replace(msg, token, to_string(value), global: false)
        false -> msg
      end
    end)
  end

  def handle_error(result, assoc \\ nil) do

    case result do
      {:error, %{errors: errors, changes: changes}} ->

        errors = errors ++
          Map.get(changes, assoc, %{errors: []}).errors

        outError = errors
        |> Enum.map(fn {key, {value, options}} = error ->
          string_key = case Keyword.has_key?(options, :id) do
            true -> Atom.to_string(key) <> "-" <> (Keyword.get(options, :id) |> to_string())
            false -> Atom.to_string(key)
          end

          message = Atom.to_string(key) <> ": " <> translate_error({value, options})
          %{message: message, db_field: string_key}
        end)

        {:error, outError}
      x -> x
    end
  end

  defp handle_errors_with_assoc_rec(%{errors: errors, changes: changes}, prefix \\ "") do

    changes_errors = changes
      |> Map.to_list()
      |> Enum.flat_map(fn {key, value} ->
        handle_errors_with_assoc_rec(value, Atom.to_string(key) <> "_")
      end)

    outError = errors
    |> Enum.map(fn {key, {value, options}} ->
      message = prefix <> Atom.to_string(key) <> ": " <> translate_error({value, options})
      %{message: message, db_field: prefix <> Atom.to_string(key)}
    end)

    outError ++ changes_errors
  end
  defp handle_errors_with_assoc_rec(_, _) do
    []
  end

  def handle_errors_with_assoc(result) do
    case result do
      {:error, error} ->
        {:error, handle_errors_with_assoc_rec(error)}
      x -> x
    end
  end
end
