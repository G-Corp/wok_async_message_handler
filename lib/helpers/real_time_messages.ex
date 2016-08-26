defmodule WokAsyncMessageHandler.Helpers.RealTimeMessages do

  @spec build_and_store(module, map, map) :: {:ok, EctoProducerMessage.t} | {:error, term}
  def build_and_store(handler, data, options \\ %{}) do
    partition_key = Map.get(data, Map.get(options, :pkey)) || List.first(Map.values data)
    topic_partition = {handler.realtime_topic, partition_key}
    from = Map.get(options, :from) || handler.producer_name
    to = Map.get(options, :to) || "#{handler.producer_name}/real_time/notify"
    message = [
      %{
          version: 1, 
          payload: Map.put_new(data, :source, handler.producer_name)
        }
    ]
    handler.build_and_store_message(topic_partition, from, to, message)
  end

end
