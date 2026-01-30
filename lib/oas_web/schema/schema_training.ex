import Ecto.Query, only: [from: 2]
defmodule OasWeb.Schema.SchemaTraining do
  use Absinthe.Schema.Notation

  object :training_where_time do
    field :id, :integer
    field :day_of_week, :integer
    field :start_time, :string
    field :booking_offset, :string
    field :end_time, :string
    field :recurring, :boolean
  end

  object :training_where do
    field :id, :integer
    field :name, :string
    field :credit_amount, :string
    field :trainings, list_of(:training)
    field :training_where_time, list_of(:training_where_time)
  end
  input_object :training_where_arg do
    field :id, :integer
    field :name, non_null(:string)
  end

  object :training_tag do
    field :id, :integer
    field :name, :string
  end
  input_object :training_tag_arg do
    field :id, :integer
    field :name, non_null(:string)
  end

  object :training do
    field :id, :integer
    field :training_where, :training_where
    field :when, :string
    field :attendance, :integer
    field :notes, :string
    field :commitment, :boolean
    field :training_tags, list_of(:training_tag)
    field :start_time, :string
    field :booking_offset, :string
    field :end_time, :string
  end

  object :training_queries do
    field :training, :training do
      arg :id, non_null(:integer)
      resolve fn _, %{id: id}, _ ->
        # query = from(
        #   t in Oas.Trainings.Training,

        #   select: t, where: t.id == ^id
        # )
        # result = Oas.Repo.one(query)
        result = Oas.Repo.get!(Oas.Trainings.Training, id)
        |> Oas.Repo.preload(:training_where)
        |> Oas.Repo.preload(:training_tags)
        |> Oas.Repo.preload(:attendance)
        |> (&(%{ &1 | attendance: length(&1.attendance) })).()

        {:ok, result}
      end
    end
    field :trainings, list_of(:training) do
      arg :from, non_null(:string)
      arg :to, non_null(:string)
      arg :training_tag_ids, list_of(:integer), default_value: []
      arg :training_where, list_of(:training_where_arg), default_value: []
      resolve fn _, %{
        training_tag_ids: training_tag_ids,
        from: from,
        to: to,
        training_where: training_where
      }, _ ->

        results = from(t in Oas.Trainings.Training,
          preload: [:training_where],
          left_join: a in assoc(t, :attendance),
          group_by: [t.id],
          select: %{training: t, attendance: count(a.id)},
          order_by: [desc: t.when, desc: t.id],
          left_join: tt in assoc(t, :training_tags),
          join: w in assoc(t, :training_where),
          where: ((0 == ^length(training_tag_ids)) or (tt.id in ^training_tag_ids)) and
            t.when >= ^from and t.when <= ^to and
            ((0 == ^length(training_where)) or  w.id in ^(training_where |> Enum.map(fn %{id: id} -> id end)))
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
    field :training_wheres, list_of(:training_where) do
      resolve fn _,_,_ ->
        result = from(w in Oas.Trainings.TrainingWhere,
          select: w,
          preload: [:trainings],
          order_by: [desc: w.id]
        )
        |> Oas.Repo.all()

        {:ok, result}
      end
    end
  end

  object :training_mutations do
    @desc "Insert training"
    field :insert_training, type: :training do
      arg :training_where, non_null(:training_where_arg)
      arg :when, non_null(:string)
      arg :commitment, :boolean
      arg :training_tags, non_null(list_of(:training_tag_arg))
      arg :notes, :string
      arg :start_time, :string
      arg :booking_offset, :string
      arg :end_time, :string
      resolve fn _, args, _ ->
        %{training_tags: training_tags, training_where: training_where} = args

        training_tags = training_tags
          |> Enum.map(fn
            %{id: id} -> Oas.Repo.get!(Oas.Trainings.TrainingTags, id)
            rest -> rest
          end)

        training_where = case training_where do
          %{id: id} -> Oas.Repo.get!(Oas.Trainings.TrainingWhere, id)
          data ->
            value = from(t in Oas.Config.Tokens,
              select: max(t.value)
            )
            |> Oas.Repo.one
            data |> Map.put(:credit_amount, value)
        end



        when1 = Date.from_iso8601!(args.when)
        args = %{args | when: when1 }

        %Oas.Trainings.Training{}
          |> Ecto.Changeset.cast(args, [:when, :notes, :commitment,
            :start_time, :booking_offset, :end_time])
          |> Oas.Trainings.Training.validate_time()
          |> Ecto.Changeset.put_assoc(
            :training_tags,
            training_tags
          ) |> Ecto.Changeset.put_assoc(:training_where, training_where)
          |> Oas.Repo.insert
          |> OasWeb.Schema.SchemaUtils.handle_error
      end
    end
    @desc "update training"
    field :update_training, type: :training do
      arg :id, non_null(:integer)
      arg :when, non_null(:string)
      arg :notes, :string
      arg :commitment, :boolean
      arg :training_tags, non_null(list_of(:training_tag_arg))
      arg :training_where, non_null(:training_where_arg)
      arg :start_time, :string
      arg :booking_offset, :string
      arg :end_time, :string
      resolve fn _, args, _ ->
        when1 = Date.from_iso8601!(args.when)
        args = %{args | when: when1}
        training = Oas.Repo.get!(Oas.Trainings.Training, args.id)
          |> Oas.Repo.preload(:training_tags) |> Oas.Repo.preload(:training_where)

        %{training_tags: training_tags, training_where: training_where} = args
        training_tags = training_tags
          |> Enum.map(fn
            %{id: id} -> Oas.Repo.get!(Oas.Trainings.TrainingTags, id)
            rest -> rest
          end)

        training_where = case training_where do
          %{id: id} -> Oas.Repo.get!(Oas.Trainings.TrainingWhere, id)
          rest -> rest
        end

        toSave = training
          |> Ecto.Changeset.cast(args, [:when, :notes, :commitment,
          :start_time, :booking_offset, :end_time], empty_values: [[], nil] ++ Ecto.Changeset.empty_values())
          |> Oas.Trainings.Training.validate_time()
          |> Ecto.Changeset.put_assoc(
            :training_tags,
            training_tags
          ) |> Ecto.Changeset.put_assoc(:training_where, training_where)


        out = toSave
          |> Oas.Repo.update
          |> OasWeb.Schema.SchemaUtils.handle_error


        # See if there are any tags to delete
        removedTrainingTags = Ecto.Changeset.get_change(toSave, :training_tags, [])
          |> Enum.filter(fn %{action: :replace} -> true
            _ -> false
          end)
          |> Enum.map(fn %{data: %{id: id}} -> id end)

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

        # See if there are any locations to delete
        removedTrainingWhere = Ecto.Changeset.get_change(toSave, :training_where)
        case removedTrainingWhere do
          nil -> nil
          %{action: :update, data: %{id: _id}} -> from(w in Oas.Trainings.TrainingWhere,
              as: :training_where,
              where: not(exists(
                from(
                  t in Oas.Trainings.Training,
                  where: t.training_where_id == parent_as(:training_where).id
                )
              )) and w.id == ^training.training_where.id
            )  |> Oas.Repo.delete_all
          %{action: :insert, data: %{id: _id}} -> from(w in Oas.Trainings.TrainingWhere,
              as: :training_where,
              where: not(exists(
                from(
                  t in Oas.Trainings.Training,
                  where: t.training_where_id == parent_as(:training_where).id
                )
              )) and w.id == ^training.training_where.id
            )  |> Oas.Repo.delete_all
        end


        # EO deleting
        out
      end
    end
    field :delete_training, type: :success do
      arg :id, non_null(:integer)
      resolve fn _, %{id: id}, _ ->
        training = Oas.Repo.get!(Oas.Trainings.Training, id)

        %Oas.Trainings.TrainingDeleted{}
        |> Ecto.Changeset.cast(training |> Map.from_struct(), [:when, :training_where_id])
        |> Oas.Repo.insert()

        {:ok, _result} = training |> Oas.Repo.delete()

        {:ok, %{success: true}}
      end
    end
    @desc "insert_training_tag, depricated"
    field :insert_training_tag, type: :training_tag do
      arg :name, non_null(:string)
      resolve fn _, %{name: _name}, _ ->
        # TODO remove
        # raise "Should not happen"
        # result = Oas.Repo.insert!(%Oas.Trainings.TrainingTags{name: name})
        {:error, "Should not happen"}
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
