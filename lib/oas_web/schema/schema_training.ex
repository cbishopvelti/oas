import Ecto.Query, only: [from: 2, where: 3]
defmodule OasWeb.Schema.SchemaTraining do
  use Absinthe.Schema.Notation

  object :training do
    field :id, :integer
    field :where, :string
    field :when, :string
    field :attendance, :integer
  end

  # import_types OasWeb.Schema.SchemaTypes

  object :training_queries do
    field :training, :training do
      arg :id, non_null(:integer)
      resolve fn _, %{id: id}, _ ->
        query = from(t in Oas.Trainings.Training, select: t, where: t.id == ^id)
        result = Oas.Repo.one(query)
        {:ok, result}
      end
    end
    field :trainings, list_of(:training) do
      resolve fn _, _, _ ->

        results = from(t in Oas.Trainings.Training,
          left_join: a in assoc(t, :attendance),
          group_by: [t.id],
          select: %{training: t, attendance: count(a.id)},
          order_by: [desc: t.when, desc: t.id]
        ) |> Oas.Repo.all
        |> Enum.map(fn %{training: t, attendance: a} -> %{t | attendance: a} end)

        {:ok, results}
      end
    end
  end

  object :training_mutations do
    @desc "Insert training"
    field :insert_training, type: :training do
      arg :where, non_null(:string)
      arg :when, non_null(:string)
      arg :training_tag_ids, list_of(:integer), default_value: []
      resolve fn _, args, _ ->
        %{training_tag_ids: training_tag_ids} = args 

        # DEBUG ONLY
        training_tags = [%{id: 1, name: "Thursday"}]

        


        when1 = Date.from_iso8601!(args.when)
        args = %{args | when: when1 }
          |> Map.put(:training_tags, training_tags)

        IO.puts("001")
        IO.inspect(args)

        {:ok, result} = %Oas.Trainings.Training{}
          |> Ecto.Changeset.cast(args, [:where, :when])
          |> Ecto.Changeset.cast_assoc(
            :training_tags
          )
          |> Oas.Repo.insert

        

        {:ok, result}
      end
    end
    @desc "update training"
    field :update_training, type: :training do
      arg :id, non_null(:integer)
      arg :where, non_null(:string)
      arg :when, non_null(:string)
      resolve fn _, args, _ ->
        when1 = Date.from_iso8601!(args.when)
        args = %{args | when: when1}
        training = Oas.Repo.get!(Oas.Trainings.Training, args.id)

        toSave = Ecto.Changeset.change training, args

        {:ok, result} = toSave
          |> Oas.Repo.update

        {:ok, result}
      end
    end
    field :delete_training, type: :success do
      arg :id, non_null(:integer)
      resolve fn _, %{id: id}, _ -> 
        Oas.Repo.get!(Oas.Trainings.Training, id)
          |> Oas.Repo.delete
        {:ok, %{success: true}}
      end
    end
  end
end