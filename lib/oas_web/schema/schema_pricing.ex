import Ecto.Query, only: [from: 2]
defmodule OasWeb.Schema.SchemaPricing do
  alias Mix.Tasks.Absinthe.Schema.Json
  use Absinthe.Schema.Notation

  object :pricing do
    field :id, :integer
    field :name, :string
    field :blockly_conf, :json
  end

  object :pricing_instance do
    field :id, :integer
    field :name, :string
    field :is_active, :boolean
    field :blockly_conf, :json
    field :pricing, :pricing
    field :trainings, list_of(:training)
  end

  object :pricing_queries do
    field :pricing, :pricing do
      arg :id, non_null(:integer)
      resolve fn _, %{id: id}, _ ->
        pricing = Oas.Repo.get!(Oas.Pricing.Pricing, id)

        {:ok, pricing}
      end
    end

    field :pricings, list_of(:pricing) do
      resolve fn _, _, _ ->
        out = from(Oas.Pricing.Pricing,
          where: true,
          order_by: [desc: :updated_at]
        )
        |> Oas.Repo.all()

        {:ok, out}
      end
    end

    field :pricing_instance, :pricing_instance do
      arg :id, non_null(:integer)
      resolve fn _, %{id: id}, _ ->
        pricing_instance = Oas.Repo.get!(Oas.Pricing.PricingInstance, id)
        |> Oas.Repo.preload(:pricing)
        |> Oas.Repo.preload(:trainings)

        {:ok, pricing_instance}
      end
    end
  end

  object :pricing_mutations do
    field :pricing, :pricing do
      arg :id, :integer
      arg :name, non_null(:string)
      arg :blockly_conf, non_null(:json)
      resolve fn _, args, _ ->

        pricing = case Map.get(args, :id) do
          nil -> %Oas.Pricing.Pricing{}
          id -> Oas.Repo.get!(Oas.Pricing.Pricing, id)
        end

        pricing
        |> Oas.Pricing.Pricing.changeset(args)
        |> (&(case &1 do
          %{data: %{id: nil}} -> Oas.Repo.insert(&1)
          %{data: %{id: _}} -> Oas.Repo.update(&1)
        end)).()
        |> OasWeb.Schema.SchemaUtils.handle_error
      end
    end

    field :pricing_instance, :pricing_instance do
      arg :id, :integer
      arg :name, non_null(:string)
      arg :is_active, :boolean
      arg :blockly_conf, :json
      arg :blockly_lua, non_null(:string)
      arg :pricing_id, non_null(:integer)
      resolve fn _, args, _ ->

        pricing = case Map.get(args, :id) do
          nil -> %Oas.Pricing.PricingInstance{}
          id -> Oas.Repo.get!(Oas.Pricing.PricingInstance, id)
        end

        pricing
        |> Oas.Pricing.PricingInstance.changeset(args)
        |> (&(case &1 do
          %{data: %{id: nil}} -> Oas.Repo.insert(&1)
          %{data: %{id: _}} -> Oas.Repo.update(&1)
        end)).()
        |> OasWeb.Schema.SchemaUtils.handle_error
      end
    end

    field :pricing_instance_add_training, :training do
      arg :training_id, non_null(:integer)
      arg :pricing_instance_id, non_null(:integer)
      resolve fn _, %{training_id: training_id, pricing_instance_id: pricing_instance_id}, _ ->
        training = Oas.Repo.get!(Oas.Trainings.Training, training_id)
        pricing_instance = Oas.Repo.get!(Oas.Pricing.PricingInstance, pricing_instance_id)

        Oas.Trainings.Training.assign_pricing_changeset(training, pricing_instance)
        |> Oas.Repo.update()
        |> OasWeb.Schema.SchemaUtils.handle_error
      end
    end

    field :pricing_instance_delete_training, :success do
      arg :training_id, non_null(:integer)
      arg :pricing_instance_id, non_null(:integer)
      resolve fn _, %{training_id: training_id, pricing_instance_id: pricing_instance_id}, _ ->
        case Oas.Repo.get(Oas.Trainings.Training, training_id) do
          nil ->
            {:error, %{message: "Training not found", db_field: "training_id"}}

          %Oas.Trainings.Training{pricing_instance_id: ^pricing_instance_id} = training ->
            training
            |> Ecto.Changeset.change(pricing_instance_id: nil)
            |> Oas.Repo.update()
            |> case do
              {:ok, _updated_training} ->
                {:ok, %{success: true}}

              error ->
                OasWeb.Schema.SchemaUtils.handle_error(error)
            end

          _training ->
            {:error, %{message: "Id's do not match", db_field: "training_id"}}
        end
      end
    end
  end
end
