defmodule WokAsyncMessageHandler.MessagesHandlers.Ecto do
  @behaviour Wok.Producer

  alias WokAsyncMessageHandler.Models.EctoProducerMessage
  alias WokAsyncMessageHandler.Models.StoppedPartition

  require Logger
  import Ecto.Query

  @spec messages(String.t, integer, integer) :: list(tuple)
  def messages(topic, partition, number_of_messages) do
    case Application.ensure_started(:ecto) do
      :ok ->
        try do
          Doteki.get_env([:wok_async_message_handler, :messages_repo])
                .all(from pm in EctoProducerMessage, 
                     limit: ^number_of_messages, 
                     where: pm.topic == ^topic 
                        and pm.partition == ^partition,
                     order_by: pm.id)
          |> Enum.map(fn(message) -> {message.id, topic, partition, message.blob} end)
        rescue
          e ->
            Logger.warn("WokAsyncMessageHandler.MessagesHandlers.Ecto : exception #{inspect e.message}. Rseturn empty list of messages to produce.")
            :timer.sleep(1000) # to prevent DB spamming in case of troubles
            []
        end
      _ ->
        Logger.warn("WokAsyncMessageHandler.MessagesHandlers.Ecto : ecto not started ? return empty list of messages to produce.")
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
        stop_partition(message_id, "#{__MODULE__} error while sending message #{message_id}\n#{inspect error}\nproducer exited.")
        :exit
      {:stop, middleware, error} ->
        stop_partition(message_id, "#{__MODULE__} message #{message_id} delivery stopped by middleware #{middleware}\n#{inspect error}\nproducer exited.")
        :exit
    end
  end

  @spec delete_row(integer) :: :next | :exit
  defp delete_row(message_id) do
    case Doteki.get_env([:wok_async_message_handler, :messages_repo]).delete(%EctoProducerMessage{id: message_id}) do
      {:error, error} ->
        stop_partition(message_id, "#{__MODULE__} unable to delete row #{message_id}\n#{inspect error}\nproducer exited.")
        :exit
      {:ok, _postgrex_result} -> #%Postgrex.Result{columns: nil, command: :delete, connection_id: 32823, num_rows: 1, rows: nil}}
        :next
    end
  end

  @spec stop_partition(integer, String.t) :: no_return
  defp stop_partition(message_id, error) do
    __MODULE__.log_warning(error)
    message = Doteki.get_env([:wok_async_message_handler, :messages_repo]).get(EctoProducerMessage, message_id)
    Doteki.get_env([:wok_async_message_handler, :messages_repo]).insert!(%StoppedPartition{topic: message.topic, partition: message.partition, message_id: message_id, error: error})
  end

  @spec log_warning(String.t) :: no_return
  def log_warning(message), do: Logger.warn(message)
end
