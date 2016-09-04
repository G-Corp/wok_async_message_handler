defmodule WokAsyncMessageHandler.Models.ConsumerMessageIndex do
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @accepted_params ~w(from id_message)a
  @required_params ~w(from id_message)a

  schema "consumer_message_indexes" do
    field :from, :string
    field :id_message, :integer
    timestamps
  end

  def changeset(record, params \\ :invalid) do
    record
    |> cast(params, @accepted_params)
    |> validate_required(@required_params)
  end
end
