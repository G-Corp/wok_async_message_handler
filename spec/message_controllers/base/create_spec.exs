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
  let! :unprocessed_event, do: TestMessage.build_event_message(payload, from_bot, 402, [metadata: %{my_metadata: 9}])

  let :before_create_event_data, do: %{
      attributes: %{error: "new error", id: 1, message_id: 1224, partition: 1, topic: "create"},
      body: %{
        "metadata" => %{"my_metadata" => 9}, 
        "payload" => %{
          "error" => "new error", "id" => 1, "message_id" => 1224, "partition" => 1, "topic" => "create"}, 
        "version" => 1
      },
      payload: %{"error" => "new error", "id" => 1, "message_id" => 1224, "partition" => 1, "topic" => "create"},
      record: struct(StoppedPartition)
    }

    let :after_create_event_data, do: Map.merge(
      before_create_event_data,
      %{
        added_data: :my_bc_added_data,
        record: Repo.one(StoppedPartition)
      }
    )

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
    it do: expect(TestMessageController).to accepted(:test_before_create, [before_create_event_data], count: 1)
    it do: expect(TestMessageController).to accepted(:test_after_create, [after_create_event_data], count: 1)
  end
end