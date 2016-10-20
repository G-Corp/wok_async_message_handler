defmodule WokAsyncMessageHandler.Helpers.TestMessage do
  def build_event_message(payload, from, message_id, options \\ []) do
    :wok_message.build_event_message(payload,
                                     from,
                                     message_id, 
                                     &__MODULE__.build_message_body/2,
                                     options)
  end

  def build_message_body(payload, options) do
    body = %{version: Keyword.get(options, :version, 1), payload: payload}
    metadata = Keyword.get(options, :metadata, nil)
    unless is_nil(metadata), do: body = Map.put(body, :metadata, metadata)
    Poison.encode! [body]
  end

  def build_wok_message(topic, key, from, to, body) do
    Wok.Message.encode_message(
      {topic, key},
      from,
      to,
      [body] |> Poison.encode!
    )
    |> elem(3)
  end
end
