defmodule WokAsyncMessageHandler.MessagesHandlers.Ecto do
  @behaviour Wok.Producer

  alias WokAsyncMessageHandler.Models.EctoProducerMessage

  require Logger
  import Ecto.Query

  @spec messages([{topic :: String.t, [partition :: integer]}], number_of_messages :: integer) ::
        [{message_id :: integer, topic :: String.t, partition :: integer, message :: term}]
  def messages(topics_partitions, number_of_messages) do
    case Application.ensure_started(:ecto) do
      :ok ->
        try do
          # TODO rewrite this to use a single query for all topics - I can't see how
          # to do this without Ecto 2.1's `or_where` and we're on 2.0.x for now.
          topics_partitions
          |> Enum.flat_map(fn {topic, partitions}->
            (from pm in EctoProducerMessage,
              where: pm.topic == ^topic
                 and pm.partition in ^partitions,
              order_by: pm.id,
              limit: ^number_of_messages,
              select: {pm.id, pm.topic, pm.partition, pm.blob})
            |> messages_repo.all
          end)
        rescue
          e ->
            __MODULE__.log_warning("WokAsyncMessageHandler.MessagesHandlers.Ecto : exception #{inspect e.message}. Return empty list of messages to produce.")
            :timer.sleep(1000) # to prevent DB spamming in case of troubles
            []
        end
      _ ->
        __MODULE__.log_warning("WokAsyncMessageHandler.MessagesHandlers.Ecto : ecto not started ? Return empty list of messages to produce.")
        :timer.sleep(1000) # to prevent DB spamming in case of troubles
        []
    end
  end

  @spec response(ok_message_ids :: [integer], ko_message_ids :: [integer]) :: :ok | :stop
  def response(ok_message_ids, ko_message_ids) do
    :ok = delete_rows(ok_message_ids)
    case ko_message_ids do
      [] ->
        :ok
      _ ->
        __MODULE__.log_warning("WokAsyncMessageHandler.MessagesHandlers.Ecto: some messages were not sent to Kafka and will be retried (#{inspect ko_message_ids})")
        :ok
    end
  end

  @spec delete_rows(message_ids :: [integer]) :: :ok
  defp delete_rows(message_ids) do
    try do
      {_deleted, _} =
        from(m in EctoProducerMessage, where: m.id in ^message_ids)
        |> messages_repo.delete_all()
    rescue
      e -> __MODULE__.log_warning("WokAsyncMessageHandler.MessagesHandlers.Ecto: error while deleting produced messages #{inspect e.message}.")
    end
    :ok
  end

  @spec messages_repo() :: atom
  defp messages_repo do
    Doteki.get_env([:wok_async_message_handler, :messages_repo])
  end

  @spec log_warning(String.t) :: term
  def log_warning(message), do: Logger.warn(message)
end
