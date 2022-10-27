import Ecto.Query, only: [from: 2, where: 3]
defmodule OasWeb.Schema.SchemaTraining do
  use Absinthe.Schema.Notation

  

  object :training_tag do
    field :id, :integer
    field :name, :string
  end
  object :training do
    field :id, :integer
    field :where, :string
    field :when, :string
    field :attendance, :integer
    field :training_tags, list_of(:training_tag)
  end
  
  # import_types OasWeb.Schema.SchemaTypes

  object :training_queries do
    field :training, :training do
      arg :id, non_null(:integer)
      resolve fn _, %{id: id}, _ ->
        # query = from(
        #   t in Oas.Trainings.Training,

        #   select: t, where: t.id == ^id
        # )
        # result = Oas.Repo.one(query)
        result = Oas.Repo.get!(Oas.Trainings.Training, id) |> Oas.Repo.preload(:training_tags)
        {:ok, result}
      end
    end
    field :trainings, list_of(:training) do
      arg :from, non_null(:string)
      arg :to, non_null(:string)
      arg :training_tag_ids, list_of(:integer), default_value: []
      resolve fn _, %{training_tag_ids: training_tag_ids, from: from, to: to}, _ ->

        results = from(t in Oas.Trainings.Training,
          left_join: a in assoc(t, :attendance),
          group_by: [t.id],
          select: %{training: t, attendance: count(a.id)},
          order_by: [desc: t.when, desc: t.id],
          left_join: tt in assoc(t, :training_tags),
          where: ((0 == ^length(training_tag_ids)) or (tt.id in ^training_tag_ids)) and
            t.when >= ^from and t.when <= ^to
        ) |> Oas.Repo.all
        |> Enum.map(fn %{training: t, attendance: a} -> %{t | attendance: a} end)

        {:ok, results}
      end
    end
    field :training_tags, list_of(:training_tag) do
      resolve fn _, _, _ ->
        result = Oas.Repo.all(from(t in Oas.Trainings.TrainingTags, select: t))
        {:ok, result}
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

        training_tags = training_tag_ids
          |> Enum.map(fn id -> Oas.Repo.get!(Oas.Trainings.TrainingTags, id) end)


        when1 = Date.from_iso8601!(args.when)
        args = %{args | when: when1 }

        {:ok, result} = %Oas.Trainings.Training{}
          |> Ecto.Changeset.cast(args, [:where, :when])
          |> Ecto.Changeset.put_assoc(
            :training_tags,
            training_tags
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
      arg :training_tag_ids, list_of(:integer), default_value: []
      resolve fn _, args, _ ->
        when1 = Date.from_iso8601!(args.when)
        args = %{args | when: when1}
        training = Oas.Repo.get!(Oas.Trainings.Training, args.id)
          |> Oas.Repo.preload(:training_tags)

        %{training_tag_ids: training_tag_ids} = args
        training_tags = training_tag_ids
          |> Enum.map(fn id -> Oas.Repo.get!(Oas.Trainings.TrainingTags, id) end)

        IO.puts("001")
        toSave = training
          |> Ecto.Changeset.cast(args, [:where, :when])
          |> Ecto.Changeset.put_assoc(
            :training_tags,
            training_tags
          )

        {:ok, result} = toSave
          |> Oas.Repo.update

        # See if there are any tags to delete
        removedTrainingTags = Ecto.Changeset.get_change(toSave, :training_tags, [])
          |> Enum.filter(fn %{action: :replace} -> true
            _ -> false
          end)
          |> Enum.map(fn %{data: %{id: id}} -> id end)

        IO.puts("005")
        IO.inspect(removedTrainingTags)

        from(
          tt in Oas.Trainings.TrainingTags,
          as: :training_tags,
          where: not(exists(
            from(
              c in "training_training_tags",
              where: c.training_tag_id == parent_as(:training_tags).id,
              select: 1
            )
          )) and tt.id in ^removedTrainingTags
        ) |> Oas.Repo.delete_all

        # removedTrainingTags |>
        # delete from training_tags where not EXISTS(SELECT 1 from training_training_tags where training_training_tags.training_tag_id = training_tags.id)

        # delete from 


        # EO see if there are any tags to delete

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
    field :insert_training_tag, type: :training_tag do
      arg :name, non_null(:string)
      resolve fn _, %{name: name}, _ ->
        result = Oas.Repo.insert!(%Oas.Trainings.TrainingTags{name: name})
        {:ok, result}
      end
    end
  end

  def testDeleteQuery do
    result = from(
      tt in Oas.Trainings.TrainingTags,
      as: :training_tags,
      where: not(exists(
        from(
          c in "training_training_tags",
          where: c.training_tag_id == parent_as(:training_tags).id,
          select: 1
        )
      ))
    ) |> Oas.Repo.all
    result
  end
end