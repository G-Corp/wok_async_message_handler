defmodule WokAsyncMessageHandler.Models.EctoProducerMessage do
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @accepted_params ~w(topic partition blob)a
  @required_params ~w(topic partition blob)a

  schema "ecto_producer_messages" do
    field :topic, :string
    field :partition, :integer
    field :blob, :string
    timestamps()
  end

  def changeset(record, params \\ :invalid) do
    record
    |> cast(params, @accepted_params)
    |> validate_required(@required_params)
  end
end
