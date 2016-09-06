defmodule WokAsyncMessageHandler.MessageControllers.Base.CreateSpec do
  use ESpec, async: false
  alias WokAsyncMessageHandler.Spec.Repo
  alias WokAsyncMessageHandler.Models.ConsumerMessageIndex
  alias WokAsyncMessageHandler.Models.StoppedPartition
  alias WokAsyncMessageHandler.MessageControllers.Base.Helpers
  alias WokAsyncMessageHandler.Helpers.TestMessage

  let! :from_bot, do: "from_bot"
  let! :topic, do: "topic"
  let! :partition, do: 1
  let! :ets_key, do: Helpers.build_ets_key(from_bot, topic, partition)
  let! :cmi, do: Repo.insert!(%ConsumerMessageIndex{from: from_bot, id_message: 401, partition: partition, topic: topic})
  let! :processed_event, do: TestMessage.build_event_message(payload, from_bot, 401)
  let! :unprocessed_event, do: TestMessage.build_event_message(payload, from_bot, 402)

  before do
    if( :ets.info(Helpers.ets_table) == :undefined ) do
      :ets.new(Helpers.ets_table, [:set, :public, :named_table])
    end
  end

  describe "#create", create: true do
    let! :payload, do: %{id: 1, topic: "create", partition: 1, message_id: 1224, error: "new error"}
    before do: allow(TestMessageController).to accept(:test_before_create)
    before do: allow(TestMessageController).to accept(:test_after_create)
    before do: {:shared, result: TestMessageController.create(unprocessed_event)}
    it do: expect(shared.result).to eq(unprocessed_event)
    it do: expect(StoppedPartition |> Repo.all |> List.first |> Map.take([:topic, :partition, :message_id, :error]))
           .to eq(%{error: "new error", message_id: 1224, partition: 1, topic: "create"})
    it do: expect(TestMessageController).to accepted(:test_before_create, :any, count: 1)
    it do: expect(TestMessageController).to accepted(:test_after_create, :any, count: 1)
  end
end