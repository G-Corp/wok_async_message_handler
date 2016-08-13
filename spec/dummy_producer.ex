defmodule WokAsyncMessageHandler.DummyProducer do
  defmodule TestMessageSerializer do
    def message_versions, do: [1]
    def created(ecto_schema, _version), do: %{id: ecto_schema.id}
    def partition_key(ecto_schema), do: ecto_schema.id
    def message_route(event), do: "bot/resource/#{event}"
  end

  @application :wok_async_message_handler
  @datastore WokAsyncMessageHandler.Repo
  @producer_name "from_bot"
  @realtime_topic "realtime_topic"
  @serializer TestMessageSerializer
  use WokAsyncMessageHandler.Bases.Ecto
end