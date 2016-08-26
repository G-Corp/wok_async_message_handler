defmodule WokAsyncMessageHandler.Spec.Helpers.MessagesSpec do
  use ESpec

  alias WokAsyncMessageHandler.Spec.Bases.DummyProducer, as: MessageProducer
  alias WokAsyncMessageHandler.Helpers.Messages

  describe "#build_and_store" do
    let :ecto_schema, do: %{__struct__: TestEctoSchema, id: "fake_id"}
    before do: allow(:kafe).to accept(:partitions, fn(_) -> [0, 1] end)
    before do: allow(MessageProducer)
               .to accept(
                :build_and_store_message, 
                fn(topic_partition, from, to, message) -> 
                  passthrough([topic_partition, from, to, message])
                end )

    context "when no error" do
      before do
        {:ok, message} = Messages.build_and_store(MessageProducer, ecto_schema, :created, "my_topic")
        {:shared, message: message}
      end
      it do: expect(MessageProducer).to accepted(
              :build_and_store_message, 
              [{"my_topic", "fake_id"}, "from_bot", "bot/resource/created", [%{payload: %{id: "fake_id"}, version: 1}]],
              count: 1
            )
    end

    context "when error" do
      before do: allow(MessageProducer).to accept(:build_and_store_message, fn(_, _, _, _) -> {:error, "error"} end )
      it do: {:error, "error"} = Messages.build_and_store(MessageProducer, ecto_schema, :created, "my_topic")
    end
  end
end