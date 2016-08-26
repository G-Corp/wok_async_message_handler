defmodule WokAsyncMessageHandler.Spec.Bases.DummyProducer do
  defmodule Serializers.TestEctoSchema do
    def message_versions, do: [1]
    def created(ecto_schema, _version), do: %{id: ecto_schema.id}
    def partition_key(ecto_schema), do: ecto_schema.id
    def message_route(event), do: "bot/resource/#{event}"
  end

  @application :wok_async_message_handler
  @datastore WokAsyncMessageHandler.Spec.Repo
  @producer_name "from_bot"
  @realtime_topic "realtime_topic"
  @serializers WokAsyncMessageHandler.Spec.Bases.DummyProducer.Serializers
  use WokAsyncMessageHandler.Bases.Ecto
end