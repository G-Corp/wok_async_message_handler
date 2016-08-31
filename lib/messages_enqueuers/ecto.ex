defmodule WokAsyncMessageHandler.MessagesEnqueuers.Ecto do
  defmacro __using__(_options) do
    quote do

      alias WokAsyncMessageHandler.Models.EctoProducerMessage
      alias WokAsyncMessageHandler.Models.StoppedPartition
      alias WokAsyncMessageHandler.Helpers.Exceptions

      require Logger
      import Ecto.Query

      @spec enqueue_rtmessage(map, map) :: {:ok, EctoProducerMessage.t} | {:error, term}
      def enqueue_rtmessage(data, options \\ %{}) do
        partition_key = Map.get(data, Map.get(options, :pkey)) || List.first(Map.values data)
        topic_partition = {@realtime_topic, partition_key}
        from = Map.get(options, :from) || @producer_name
        to = Map.get(options, :to) || "#{@producer_name}/real_time/notify"
        message = [
          %{
              version: 1, 
              payload: Map.put_new(data, :source, @producer_name)
            }
        ]
        enqueue(topic_partition, from, to, message)
      end

      @spec enqueue_message(Ecto.Schema.t, :atom, String.t) :: {:ok, EctoProducerMessage.t} | {:error, term}
      def enqueue_message(ecto_schema, event, topic \\ @messages_topic) do
        serializer = schema_serializer(ecto_schema)
        message = build_message(ecto_schema, event, serializer)
        topic_partition = {topic, serializer.partition_key(ecto_schema)}
        from = @producer_name
        to = serializer.message_route(event)
        enqueue(topic_partition, from, to, message)
      end

      @spec enqueue(term, String.t, String.t, map)  :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t} | {:error, term}
      def enqueue(topic_partition, from, to, message) do
        case Wok.Message.encode_message(topic_partition, from, to, message |> Poison.encode!) do
          {:ok, topic, partition, encoded_message} ->
            @datastore.insert(%EctoProducerMessage{topic: topic, partition: partition, blob: encoded_message})
          {:error, error} -> {:error, error}
        end
      end

      @spec build_message(Ecto.Schema.t, :atom, module) :: map()
      def build_message(ecto_schema, event, serializer) do
        Enum.map(serializer.message_versions, fn(version) ->
          %{
              payload: apply(serializer, event, [ecto_schema, version]),
              version: version
            }
        end)
      end

      @spec schema_serializer(Ecto.Schema.t) :: module
      defp schema_serializer(schema) do
        schema_str = schema.__struct__
                    |> to_string
                    |> String.split(".")
                    |> List.last
        Module.concat([@serializers, schema_str])
      end
    end
  end
end
