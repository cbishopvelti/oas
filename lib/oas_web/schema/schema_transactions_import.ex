import Ecto.Query, only: [from: 2, where: 3]
defmodule OasWeb.Schema.SchemaTransactionsImport do
  use Absinthe.Schema.Notation

  object :transactions_import_error do
    field :transaction_id, :integer
    field :name, :string
  end

  object :transactions_import do
    field :account, :string
    field :date, :string
    field :bank_account_name, :string
    field :my_reference, :string
    field :member, :member do
      resolve fn
        %{who_member_id: member_id}, _, _ ->
          result = Oas.Repo.get(Oas.Members.Member, member_id)
          {:ok, result}
        _, _, _ -> {:ok, nil}
      end
    end
    field :amount, :string
    field :state, :string
    field :state_data, :string
    field :subcategory, :string
    field :tags, list_of(:string)
    field :to_import, :boolean
    field :errors, list_of(:transactions_import_error)
    field :warnings, list_of(:string)
  end

  input_object :to_import_arg do
    field :index, non_null(:integer)
    field :transaction_tags, list_of(:transaction_tag_arg)
  end

  object :transactions_import_queries do
    
    field :transactions_import, type: list_of :transactions_import do
      resolve fn _, _, %{context: %{ current_member: current_member, user_table: user_table }} ->
        # [{_, rows}] = :ets.lookup(user_table, current_member.id)
        case :ets.lookup(user_table, current_member.id) do
          [{_, rows}] -> 
            {:ok, rows}
          _ -> {:ok, nil}
        end
      end
    end
  end

  object :transactions_import_mutations do
    field :set_to_import, type: :success do
      arg :index, non_null(:integer)
      arg :to_import, non_null(:boolean)
      resolve fn _, %{index: index, to_import: to_import}, %{context: %{ user_table: user_table, current_member: current_member }} ->

        [{_, rows}] = :ets.lookup(
          user_table,
          current_member.id
        )

        row = Enum.at(rows, index);
        List.replace_at(
          rows,
          index,
          %{row | to_import: to_import}
        )
        |> (&(:ets.insert(
          user_table,
          {current_member.id, &1}
        ))).()

        {:ok, %{success: true}}
      end
    end
    field :set_tags, type: :success do
      arg :index, non_null(:integer)
      arg :tags, non_null(list_of(:string))
      resolve fn _, %{index: index, tags: tags}, %{context: %{ user_table: user_table, current_member: current_member }} ->

        [{_, rows}] = :ets.lookup(
          user_table,
          current_member.id
        )

        row = Enum.at(rows, index);
        List.replace_at(
          rows,
          index,
          %{row | tags: tags}
        )
        |> (&(:ets.insert(
          user_table,
          {current_member.id, &1}
        ))).()

        {:ok, %{success: true}}
      end
    end
    field :import_transactions_reprocess, type: :success do
      resolve fn _, _, %{context: %{ user_table: user_table, current_member: current_member }} ->
        [{_, rows}] = :ets.lookup(
          user_table,
          current_member.id
        )

        result = rows 
        |> Enum.map(fn (row) -> 
          Map.delete(row, :errors) |> Map.delete(:warnings)
        end)
        |> Oas.ImportTransactions.process

        :ets.insert(
          user_table,
          {current_member.id, result}
        )

        {:ok, %{success: true}}
      end
    end
    field :import_transactions, type: :success do
      arg :file, non_null(:upload)
      resolve fn _, %{file: file}, %{context: %{ user_table: user_table, current_member: current_member }} ->

        result = File.stream!(file.path)
        |> CSV.decode(headers: true, field_transform: fn (field) -> String.trim(field) end, validate_row_length: true)
        # |> Enum.take(1) # DEBUG ONLY
        |> Enum.filter(fn
          {:error, message} -> 
            !String.contains?(message, ":validate_row_length")
          _ -> true
        end)
        |> Enum.filter(fn {:ok, row} ->
          case row do
            %{"Account" => ""} -> false
            %{"Account" => nil} -> false
            %{"Amount" => nil} -> false
            %{"Amount" => ""} -> false
            %{"Date" => ""} -> false
            %{"Date" => nil} -> false
            _ -> true
          end
        end)
        |> Enum.map(fn
          {:ok, %{"Memo" => memo, "Account" => account, "Amount" => amount, "Date" => date, "Subcategory" => subcategory}} ->
            %{
              memo: memo,
              account: account,
              amount: Float.parse(amount) |> elem(0),
              date: Timex.parse!(date, "{0D}/{0M}/{YYYY}") |> Timex.to_date,
              tags: [subcategory]
            }
          {:error, message} ->
            raise message
        end)
        |> Enum.map(fn
          data = %{memo: memo} ->
            [bank_account_name, my_reference] = memo
              |> String.split("\t")
              |> Enum.map(fn (item) -> String.trim(item) end)

            data
            |> Map.put(:bank_account_name, bank_account_name)
            |> Map.put(:my_reference, my_reference)
        end)
        |> Oas.ImportTransactions.process

        :ets.insert(
          user_table,
          {current_member.id, result}
        )

        {:ok, %{success: true}}
      end
    end
    field :do_import_transactions, type: :success do
      # arg :indexes_to_import, non_null(list_of(:integer))
      # arg :to_import, non_null(list_of(:to_import_arg))
      
      resolve fn
        _,
        _, # %{to_import: to_import},
        %{context: %{ user_table: user_table, current_member: current_member }}
      -> 

        [{_, rows}] = :ets.lookup(user_table, current_member.id)
        rowsToImport = rows
        |> Enum.with_index
        |> Enum.filter(fn
          ({%{to_import: to_import}, _}) -> to_import
          _ -> false
        end)
        |> Enum.map(fn ({row, id}) ->
          # transaction_tags = Enum.find(to_import, fn (%{index: index}) -> index == id end)
          #   |> Map.get(:transaction_tags)

          transaction_tags = row.tags |> Enum.map(fn name -> %{name: name} end)

          {Map.put(row, :transaction_tags, transaction_tags), id}
        end)
        |> Enum.map(fn ({row, id}) -> row end)

        Oas.ImportTransactions.doImport(rowsToImport)

        :ets.delete(user_table, current_member.id)

        {:ok, %{
          success: true
        }}
      end
    end
    field :reset_import_transactions, type: :success do
      resolve fn _, _, %{context: %{ user_table: user_table, current_member: current_member }} ->
        :ets.delete(user_table, current_member.id)
        {:ok, %{success: true}}
      end
    end
  end
end