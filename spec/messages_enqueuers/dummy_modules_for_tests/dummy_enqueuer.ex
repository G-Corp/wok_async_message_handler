defmodule WokAsyncMessageHandler.MessagesEnqueuers.DummyEnqueuer do
  defmodule Serializers.TestEctoSchema do
    def message_versions, do: [1]
    def created(struct, _version), do: %{id: struct.id}
    def partition_key(struct), do: struct.id
    def message_route(event), do: "bot/resource/#{event}"
  end

  @datastore WokAsyncMessageHandler.Spec.Repo
  @producer_name "from_bot"
  @realtime_topic "realtime_topic"
  @messages_topic "messages_topic"
  @serializers WokAsyncMessageHandler.MessagesEnqueuers.DummyEnqueuer.Serializers
  use WokAsyncMessageHandler.MessagesEnqueuers.Ecto
end
