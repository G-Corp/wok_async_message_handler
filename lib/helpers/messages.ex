defmodule WokAsyncMessageHandler.Helpers.Messages do

  @spec build_and_store(module, Ecto.Schema.t, :atom, String.t) :: {:ok, EctoProducerMessage.t} | {:error, term}
  def build_and_store(handler, ecto_schema, event, topic) do
    serializer = handler.schema_serializer(ecto_schema)
    message = handler.build_message(ecto_schema, event, serializer)
    topic_partition = {topic, serializer.partition_key(ecto_schema)}
    from = handler.producer_name
    to = serializer.message_route(event)
    handler.build_and_store_message(topic_partition, from, to, message)
  end

end