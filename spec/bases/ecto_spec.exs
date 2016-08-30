defmodule WokAsyncMessageHandler.Spec.Bases.EctoSpec do
  use ESpec

  alias WokAsyncMessageHandler.Spec.Repo
  alias WokAsyncMessageHandler.Models.EctoProducerMessage
  alias WokAsyncMessageHandler.Spec.Bases.DummyProducer, as: MessageProducer
  alias WokAsyncMessageHandler.Models.StoppedPartition
  alias WokAsyncMessageHandler.Helpers.Exceptions

  describe "#build_and_store_message" do
    let :ecto_schema, do: %{__struct__: TestEctoSchema, id: "fake_id"}
    before do
      allow(:kafe).to accept(:partitions, fn(_) -> [0, 1] end)
    end
    context "when no error" do
      before do
        allow(Repo).to accept(:insert, fn(ecto_schema) -> {:ok, ecto_schema} end )
        {:ok, message} = MessageProducer.build_and_store_message({"my_topic", "fake_id"}, "from_bot", "bot/resource/created", %{id: "fake_id"})
        {:shared, message: message}
      end
     it do: expect(Repo).to accepted(:insert, :any, count: 1)
     it do: expect(shared.message.partition).to eq(1)
     it do: expect(shared.message.topic).to eq("my_topic")
     it do: expect(shared.message.blob).to eq(Wok.Message.encode_message(
      {"my_topic", "fake_id"},
      "from_bot",
      "bot/resource/created",
      "{\"id\":\"fake_id\"}")
     |> elem(3)
     )
    end

    context "when storage error" do
      before do: allow(Repo).to accept(:insert, fn(_ecto_schema) -> {:error, "storage error"} end )
      it do: {:error, "storage error"} = MessageProducer.build_and_store_message({"my_topic", "fake_id"}, "from_bot", "bot/resource/created", %{id: "fake_id"})
    end

    context "when wok message error" do
      before do: allow(Wok.Message).to accept(:encode_message, fn(_, _, _, _) -> {:error, "wok message error"} end )
      it do: {:error, "wok message error"} = MessageProducer.build_and_store_message({"my_topic", "fake_id"}, "from_bot", "bot/resource/created", %{id: "fake_id"})
    end
  end

  describe "#messages" do
    let! :t, do: Ecto.DateTime.utc
    let! :message1, do: Repo.insert!(%EctoProducerMessage{topic: "topic_1", partition: 1, blob: "blob1", inserted_at: t, updated_at: t})
    let! :message2, do: Repo.insert!(%EctoProducerMessage{topic: "topic_2", partition: 1, blob: "blob2", inserted_at: t, updated_at: t})
    let! :message3, do: Repo.insert!(%EctoProducerMessage{topic: "topic_1", partition: 1, blob: "blob3", inserted_at: t, updated_at: t})

    context "when message fetch is ok" do
      it do: expect(MessageProducer.messages "topic_1", 1, 1).to eq([{message1.id, "topic_1", 1, "blob1"}])
      it do: expect(MessageProducer.messages "topic_2", 1, 1000).to eq([{message2.id, "topic_2", 1, "blob2"}])
      it do: expect(MessageProducer.messages "topic_1", 1, 2).to eq([{message1.id, "topic_1", 1, "blob1"}, {message3.id, "topic_1", 1, "blob3"}])
    end

    context "when fetch is not ok" do
      before do: allow(Repo).to accept(:all, fn(_) -> raise "error" end)
      before do: allow(Exceptions).to accept(:throw_exception, 
        fn(exception, data, :messages, false) -> passthrough([exception, data, :messages, false]) end
      )
      it do: expect(MessageProducer.messages "topic_987", 12, 34).to eq([])
      xit do: expect(Exceptions).to accepted(:throw_exception, :any, count: 1) #spy does not work with macro ???
    end
  end

  describe "#response" do
    let! :t, do: Ecto.DateTime.utc
    let! :message, do: Repo.insert!(%EctoProducerMessage{topic: "topic", partition: 1, blob: "blob", inserted_at: t, updated_at: t})
    context "when message is sent without error" do
      before do
        {:shared, result: MessageProducer.response(message.id, {:ok, :ok}, false) }
      end
      it do: expect( shared.result ).to eq(:next)
      it do: expect( Repo.get(EctoProducerMessage, message.id) ).to eq(nil)
    end

    context "when message is sent without error but db delete does not work" do
      before do
        allow(Repo).to accept(:delete, fn(_) -> {:error, "my error"} end)
        allow(WokAsyncMessageHandler.Spec.Bases.DummyProducer).to accept(:log_warning, fn(_message) -> nil end)
        {:shared, result: MessageProducer.response(message.id, {:ok, :tuple}, true) }
      end
      it do: expect( shared.result ).to eq(:exit)
      it do: expect( WokAsyncMessageHandler.Spec.Bases.DummyProducer ).to accepted(:log_warning, :any, count: 1)
      it do: expect( StoppedPartition |> Repo.all |> List.first |> Map.take([:topic, :partition, :message_id, :error]))
             .to eq(%{topic: "topic", partition: 1, message_id: message.id, error: "WokAsyncMessageHandler.MessagesProducers.Ecto unable to delete row #{message.id}\n\"my error\"\nproducer exited."})
    end

    context "when message is not sent" do
      let! :message, do: Repo.insert!(%EctoProducerMessage{topic: "topic2", partition: 3, blob: "blob123", inserted_at: t, updated_at: t})
      before do
        allow(WokAsyncMessageHandler.Spec.Bases.DummyProducer).to accept(:log_warning, fn(_message) -> nil end)
        {:shared, result: MessageProducer.response(message.id, {:error, "an error"}, true) }
      end
      it do: expect( shared.result ).to eq(:exit)
      it do: expect( WokAsyncMessageHandler.Spec.Bases.DummyProducer ).to accepted(:log_warning, :any, count: 1)
      it do: expect( StoppedPartition |> Repo.all |> List.first |> Map.take([:topic, :partition, :message_id, :error]))
            .to eq(%{topic: "topic2", partition: 3, message_id: message.id, error: "WokAsyncMessageHandler.MessagesProducers.Ecto error while sending message #{message.id}\n\"an error\"\nproducer exited."})
    end

    context "when a middleware stop message sending" do
      let! :message, do: Repo.insert!(%EctoProducerMessage{topic: "topic23", partition: 5, blob: "blob987", inserted_at: t, updated_at: t})
      before do
        allow(WokAsyncMessageHandler.Spec.Bases.DummyProducer).to accept(:log_warning, fn(_message) -> nil end)
        {:shared, result: MessageProducer.response(message.id, {:stop, "middleware", "middle_error"}, true) }
      end
      it do: expect( shared.result ).to eq(:exit)
      it do: expect( WokAsyncMessageHandler.Spec.Bases.DummyProducer ).to accepted(:log_warning, :any, count: 1)
      it do: expect( StoppedPartition |> Repo.all |> List.first |> Map.take([:topic, :partition, :message_id, :error]))
            .to eq(%{topic: "topic23", partition: 5, message_id: message.id, error: "WokAsyncMessageHandler.MessagesProducers.Ecto message #{message.id} delivery stopped by middleware middleware\n\"middle_error\"\nproducer exited."})
    end
  end
end