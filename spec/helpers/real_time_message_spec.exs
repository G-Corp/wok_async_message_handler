defmodule BotsUnit.Spec.Helpers.RealTimeMessageSpec do
  use ESpec

  alias WokAsyncMessageHandler.Spec.Bases.DummyProducer, as: MessageProducer
  alias WokAsyncMessageHandler.Helpers.RealTimeMessage

  describe "#build_and_store" do
    before do: allow(:kafe).to accept(:partitions, fn(_) -> [0, 1, 2] end)
    before do: allow(MessageProducer)
               .to accept(
                :build_and_store_message, 
                fn(topic_partition, from, to, message) -> 
                  passthrough([topic_partition, from, to, message])
                end )

    context "without options" do
      context "when no error" do
        before do
          {:ok, message} = RealTimeMessage.build_and_store(MessageProducer, %{session_id: "my_session_id"})
          {:shared, message: message}
        end
        it do: expect(MessageProducer).to accepted(
              :build_and_store_message, 
              [
                {"realtime_topic", "my_session_id"}, 
                "from_bot", 
                "from_bot/real_time/notify",
                [%{payload: %{session_id: "my_session_id", source: "from_bot"}, version: 1}]
              ],
              count: 1
            )
      end
  
      context "when error" do
        before do: allow(MessageProducer).to accept(:build_and_store_message, fn(_, _, _, _) -> {:error, "error"} end )
        it do: {:error, "error"} = RealTimeMessage.build_and_store(MessageProducer, %{session_id: "my_session_id"})
      end
    end

    context "with options" do
      before do
        {:ok, message} = RealTimeMessage.build_and_store(
          MessageProducer, 
          %{session_id: "my_session_id", data_for_pkey: "123", source: "my_source"},
          %{pkey: :data_for_pkey, from: "my_from", to: "my_to"}
        )
        {:shared, message: message}
      end
      it do: expect(MessageProducer).to accepted(
              :build_and_store_message, 
              [
                {"realtime_topic", "123"}, 
                "my_from", 
                "my_to",
                [%{payload: %{data_for_pkey: "123", session_id: "my_session_id", source: "my_source"}, version: 1}]
              ],
              count: 1
            )
    end
  end
end
