defmodule WokAsyncMessageHandler.Helpers.TestMessage do
  require Record

  Record.defrecord(:message_transfert, 
    Record.extract(
      :message_transfert, 
      from_lib: "wok_message_handler/include/wok_message_handler.hrl"
      )
    ) 

  Record.defrecord(:wok_msg,
    Record.extract(
      :wok_msg, 
      from_lib: "wok_message_handler/include/wok_message_handler.hrl"
      )
    )

  Record.defrecord(:message,
   Record.extract(
     :message, 
     from_lib: "wok_message_handler/include/wok_message_handler.hrl"
     )
   )

  def build_event_message(payload, from, message_id, options \\ []) do
    message_transfert(
      message: build_message(payload, from, message_id, options),
      partition: Keyword.get(options, :partition, 1),
      topic: Keyword.get(options, :topic, "topic"),
    )
  end

  defp build_message(payload, from, message_id, options) do
    wok_msg(
      message: message(
        uuid: Ecto.UUID.generate,
        to: "to_bot",
        from: from,
        params: %{},
        headers: %{message_id: message_id},
        body: build_message_body(payload, options)
      )
    )
  end

  defp build_message_body(payload, options) do
    body = %{version: Keyword.get(options, :version, 1), payload: payload}
    metadata = Keyword.get(options, :metadata, nil)
    unless is_nil(metadata), do: body = Map.put(body, :metadata, metadata)
    Poison.encode! [body]
  end

  def payload_to_wok_message(topic, key, from, to, body) do
    Wok.Message.encode_message(
      {topic, key},
      from,
      to,
      [body] |> Poison.encode!
    )
    |> elem(3)
  end
end
