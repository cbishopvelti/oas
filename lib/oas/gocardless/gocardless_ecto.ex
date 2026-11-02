defmodule Oas.Gocardless.GocardlessEcto do
	use Ecto.Schema
	import Ecto.Changeset

	schema "gocardless" do
	  field :name, :string
		field :type, Ecto.Enum, values: [:member, :training_where]

    has_one :member, Oas.Members.Member, on_replace: :nilify, foreign_key: :gocardless_id
    has_one :training_where, Oas.Trainings.TrainingWhere, foreign_key: :gocardless_id

    timestamps()
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [ :name, :type])
    |> validate_required([:name, :type])
    |> unique_constraint(:name)
  end

end
