defmodule OasWeb.Channels.Utils do

  # Safe to push to client
  def socket_to_member_map(socket) do

    member = if current_member = socket.assigns[:current_member] do
      member_data =
        current_member
        |> Map.from_struct()
        |> Map.take([:id, :name, :is_admin, :is_reviewer])

      member_data
    else
      nil
    end

    member
  end
end
