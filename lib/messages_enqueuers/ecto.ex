defmodule WokAsyncMessageHandler.MessagesEnqueuers.Ecto do
  defmacro __using__(_options) do
    quote do

      alias WokAsyncMessageHandler.Models.EctoProducerMessage
      alias WokAsyncMessageHandler.Models.StoppedPartition
      alias WokAsyncMessageHandler.Helpers.Exceptions

      import Ecto.Query

      @spec enqueue_rtmessage(map, map) :: {:ok, EctoProducerMessage.t} | {:error, term}
      def enqueue_rtmessage(data, options \\ []) do
        partition_key = Map.get(data, Keyword.get(options, :pkey)) || List.first(Map.values data)
        topic_partition = {@realtime_topic, partition_key}
        from = Keyword.get(options, :from, @producer_name)
        to = Keyword.get(options, :to, "#{@producer_name}/real_time/notify")
        message = %{version: 1, payload: Map.put_new(data, :source, @producer_name)}
        message = case Keyword.get(options, :metadata) do
          nil -> message
          metadata -> Map.put(message, :metadata, metadata)
        end
        enqueue(topic_partition, from, to, [message])
      end

      @spec enqueue_message(Ecto.Schema.t, :atom, [metadata: map, topic: String.t]) :: {:ok, EctoProducerMessage.t} | {:error, term}
      def enqueue_message(%{__struct__: _} = ecto_struct, event, options \\ []) when is_atom(event) do
        serializer = schema_serializer(ecto_struct)
        message = build_message(ecto_struct, event, serializer, Keyword.get(options, :metadata))
        topic_partition = {Keyword.get(options, :topic, @messages_topic), serializer.partition_key(ecto_struct)}
        from = @producer_name
        to = serializer.message_route(event)
        enqueue(topic_partition, from, to, message)
      end

      @spec enqueue_simple_message(map | list, map) :: {:ok, EctoProducerMessage.t} | {:error, term}
      def enqueue_simple_message(data, options \\ []) do
        partition_key = partition_key(data, options)
        topic_partition = {Keyword.get(options, :topic, @messages_topic), partition_key}
        from = Keyword.get(options, :from, @producer_name)
        to = Keyword.get(options, :to, @producer_name)
        message = %{version: 1, payload: data}
        message = case Keyword.get(options, :metadata) do
          nil -> message
          metadata -> Map.put(message, :metadata, metadata)
        end
        enqueue(topic_partition, from, to, [message])
      end
      defp partition_key([data|_], options), do: partition_key(data, options)
      defp partition_key(data, options) when is_map(data) do
        Map.get(data, Keyword.get(options, :pkey)) || List.first(Map.values data)
      end

      @spec enqueue(term, String.t, String.t, map) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t} | {:error, term}
      def enqueue(topic_partition, from, to, message) do
        case Wok.Message.encode_message(topic_partition, from, to, message |> Poison.encode!) do
          {:ok, topic, partition, encoded_message} ->
            @datastore.insert(%EctoProducerMessage{topic: topic, partition: partition, blob: encoded_message})
          {:error, error} -> {:error, error}
        end
      end

      @spec build_message(Ecto.Schema.t, :atom, module) :: map()
      def build_message(ecto_struct, event, serializer, metadata \\ nil) do
        Enum.map(serializer.message_versions, fn(version) ->
          message = %{
              payload: apply(serializer, event, [ecto_struct, version]),
              version: version
            }
          if metadata == nil, do: message, else: Map.put(message, :metadata, metadata)
        end)
      end

      @spec schema_serializer(Ecto.Schema.t) :: module
      defp schema_serializer(ecto_struct) do
        ecto_struct_str = ecto_struct.__struct__
                    |> to_string
                    |> String.split(".")
                    |> List.last
        Module.concat([@serializers, ecto_struct_str])
      end
    end
  end
end
