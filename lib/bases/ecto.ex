defmodule WokAsyncMessageHandler.Bases.Ecto do
  defmacro __using__(_options) do
    quote do
      @behaviour Wok.Producer

      alias WokAsyncMessageHandler.Models.EctoProducerMessage
      alias WokAsyncMessageHandler.Models.StoppedPartition
      alias WokAsyncMessageHandler.Helpers.Exceptions

      require Logger
      import Ecto.Query

      def realtime_topic, do: @realtime_topic
      def producer_name, do: @producer_name

      @spec create_and_add_rt_notification_to_message_queue(map) :: {:ok, EctoProducerMessage.t} | {:error, term}
      def create_and_add_rt_notification_to_message_queue(data, options \\ %{}) do
        Logger.info "WokAsyncMessageHandler.Bases.Ecto.create_and_add_rt_notification_to_message_queue/2 is deprecated. Use WokAsyncMessageHandler.Helpers.RealTimeMessages.build_and_store/3 instead."
        WokAsyncMessageHandler.Helpers.RealTimeMessages.build_and_store(__MODULE__, data, options)
      end

      @spec create_and_add_message_to_message_queue(Ecto.Schema.t, :atom, String.t) :: {:ok, EctoProducerMessage.t} | {:error, term}
      def create_and_add_message_to_message_queue(ecto_schema, event, topic) do
        Logger.info "WokAsyncMessageHandler.Bases.Ecto.create_and_add_message_to_message_queue/3 is deprecated. Use WokAsyncMessageHandler.Helpers.Message.build_and_store/4 instead."
        WokAsyncMessageHandler.Helpers.Messages.build_and_store(__MODULE__, ecto_schema, event, topic)
      end

      @spec build_and_store_message(term, String.t, String.t, map)  :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t} | {:error, term}
      def build_and_store_message(topic_partition, from, to, message) do
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

      @spec messages(String.t, integer, integer) :: list(tuple)
      def messages(topic, partition, number_of_messages) do
        try do
          @datastore.all(from pm in EctoProducerMessage, limit: ^number_of_messages, where: pm.topic == ^topic and pm.partition == ^partition, order_by: pm.id)
          |> Enum.map(fn(message) -> {message.id, topic, partition, message.blob} end)
        rescue
          e ->
            Exceptions.throw_exception(
              e, 
              %{topic: topic, partition: partition, number_of_messages: number_of_messages}, 
              :messages, 
              false
            )
            :timer.sleep(1000) # to prevent DB spamming in case of troubles
            []
        end
      end

      @spec response(integer, term, boolean) :: :next | :exit | :retry
      def response(message_id, response, retry \\ false) do
        process_response(message_id, response, retry)
      end

      @spec process_response(integer, term, boolean) :: :next | :exit | :retry
      def process_response(message_id, response, _retry) do
        case response do
          {:ok, _} ->
            delete_row(message_id)
          {:error, error} ->
            stop_partition(message_id, "WokAsyncMessageHandler.MessagesProducers.Ecto error while sending message #{message_id}\n#{inspect error}\nproducer exited.")
            :exit
          {:stop, middleware, error} ->
            stop_partition(message_id, "WokAsyncMessageHandler.MessagesProducers.Ecto message #{message_id} delivery stopped by middleware #{middleware}\n#{inspect error}\nproducer exited.")
            :exit
        end
      end

      @spec delete_row(integer) :: :next | :exit
      defp delete_row(message_id) do
        case @datastore.delete(%EctoProducerMessage{id: message_id}) do
          {:error, error} ->
            stop_partition(message_id, "WokAsyncMessageHandler.MessagesProducers.Ecto unable to delete row #{message_id}\n#{inspect error}\nproducer exited.")
            :exit
          {:ok, _postgrex_result} -> #%Postgrex.Result{columns: nil, command: :delete, connection_id: 32823, num_rows: 1, rows: nil}}
            :next
        end
      end

      @spec stop_partition(integer, String.t) :: no_return
      defp stop_partition(message_id, error) do
        __MODULE__.log_warning(error)
        message = @datastore.get(EctoProducerMessage, message_id)
        @datastore.insert!(%StoppedPartition{topic: message.topic, partition: message.partition, message_id: message_id, error: error})
      end

      @spec log_warning(String.t) :: no_return
      def log_warning(message), do: Logger.warn(message)

      @spec schema_serializer(Ecto.Schema.t) :: module
      def schema_serializer(schema) do
        schema_str = schema.__struct__
                    |> to_string
                    |> String.split(".")
                    |> List.last
        Module.concat([@serializers, schema_str])
      end
    end
  end
end
