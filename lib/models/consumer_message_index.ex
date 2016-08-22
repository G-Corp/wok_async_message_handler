defmodule WokAsyncMessageHandler.Models.ConsumerMessageIndex do
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @accepted_params ~w(id_message partition topic)a
  @required_params ~w(id_message partition topic)a

  schema "consumer_message_indexes" do
    field :topic, :string
    field :partition, :integer
    field :id_message, :integer
    timestamps
  end

  def changeset(record, params \\ :invalid) do
    record
    |> cast(params, @accepted_params)
    |> validate_required(@required_params)
  end
end
