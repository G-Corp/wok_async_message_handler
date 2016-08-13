defmodule BotsUnit.MessagesProducers.EctoSpec do
  use ESpec

  alias WokAsyncMessageHandler.Repo
  alias WokAsyncMessageHandler.Models.EctoProducerMessage
  alias WokAsyncMessageHandler.DummyProducer, as: MessageProducer
  alias WokAsyncMessageHandler.Models.StoppedPartition

  describe "#create_and_add_rt_notification_to_message_queue" do
    before do: allow(:kafe).to accept(:partitions, fn(_) -> [0, 1, 2] end)
    context "when no error" do
      before do
        allow(Repo).to accept(:insert, fn(ecto_schema) -> {:ok, ecto_schema} end )
        {:ok, message} = MessageProducer.create_and_add_rt_notification_to_message_queue(%{session_id: "my_session_id"})
        {:shared, message: message}
      end
      it do: expect(Repo).to accepted(:insert, :any, count: 1)
      it do: expect(shared.message.partition).to eq(1)
      it do: expect(shared.message.topic).to eq("realtime_topic")
      it do: expect(shared.message.blob).to eq(Wok.Message.encode_message(
              {"realtime_topic", "my_session_id"},
              "from_bot",
              "from_bot/real_time/notify",
              "[{\"version\":1,\"payload\":{\"source\":\"from_bot\",\"session_id\":\"my_session_id\"}}]")
              |> elem(3)
            )
    end

    context "when storage error" do
      before do: allow(Repo).to accept(:insert, fn(_ecto_schema) -> {:error, "storage error"} end )
      it do: {:error, "storage error"} = MessageProducer.create_and_add_rt_notification_to_message_queue(%{session_id: "my_session_id"})
    end

    context "when wok message error" do
      before do: allow(Wok.Message).to accept(:encode_message, fn(_, _, _, _) -> {:error, "wok message error"} end )
      it do: {:error, "wok message error"} = MessageProducer.create_and_add_rt_notification_to_message_queue(%{session_id: "my_session_id"})
    end
  end

  describe "#create_and_add_message_to_message_queue" do
    let :ecto_schema, do: %{__struct__: TestEctoSchema, id: "fake_id"}
    before do
      allow(:kafe).to accept(:partitions, fn(_) -> [0, 1] end)
    end
    context "when no error" do
      before do
        allow(Repo).to accept(:insert, fn(ecto_schema) -> {:ok, ecto_schema} end )
        {:ok, message} = MessageProducer.create_and_add_message_to_message_queue(ecto_schema, :created, "my_topic")
        {:shared, message: message}
      end
     it do: expect(Repo).to accepted(:insert, :any, count: 1)
     it do: expect(shared.message.partition).to eq(1)
     it do: expect(shared.message.topic).to eq("my_topic")
     it do: expect(shared.message.blob).to eq(Wok.Message.encode_message(
      {"my_topic", "fake_id"},
      "from_bot",
      "bot/resource/created",
      "[{\"version\":1,\"payload\":{\"id\":\"fake_id\"}}]")
     |> elem(3)
     )
    end

    context "when storage error" do
      before do: allow(Repo).to accept(:insert, fn(_ecto_schema) -> {:error, "storage error"} end )
      it do: {:error, "storage error"} = MessageProducer.create_and_add_message_to_message_queue(ecto_schema, :created, "my_topic")
    end

    context "when wok message error" do
      before do: allow(Wok.Message).to accept(:encode_message, fn(_, _, _, _) -> {:error, "wok message error"} end )
      it do: {:error, "wok message error"} = MessageProducer.create_and_add_message_to_message_queue(ecto_schema, :created, "my_topic")
    end
  end

  describe "#messages" do
    let! :t, do: Ecto.DateTime.utc
    let! :message1, do: Repo.insert!(%EctoProducerMessage{topic: "topic_1", partition: 1, blob: "blob1", inserted_at: t, updated_at: t})
    let! :message2, do: Repo.insert!(%EctoProducerMessage{topic: "topic_2", partition: 1, blob: "blob2", inserted_at: t, updated_at: t})
    let! :message3, do: Repo.insert!(%EctoProducerMessage{topic: "topic_1", partition: 1, blob: "blob3", inserted_at: t, updated_at: t})
    it do: expect(MessageProducer.messages "topic_1", 1, 1).to eq([{message1.id, "topic_1", 1, "blob1"}])
    it do: expect(MessageProducer.messages "topic_2", 1, 1000).to eq([{message2.id, "topic_2", 1, "blob2"}])
    it do: expect(MessageProducer.messages "topic_1", 1, 2).to eq([{message1.id, "topic_1", 1, "blob1"}, {message3.id, "topic_1", 1, "blob3"}])
  end

  describe "#response" do
    let! :t, do: Ecto.DateTime.utc
    let! :message, do: Repo.insert!(%EctoProducerMessage{topic: "topic", partition: 1, blob: "blob", inserted_at: t, updated_at: t})
    context "when message is sent without error" do
      before do
        {:shared, result: MessageProducer.response(message.id, {:ok, :ok}) }
      end
      it do: expect( shared.result ).to eq(:next)
      it do: expect( Repo.get(EctoProducerMessage, message.id) ).to eq(nil)
    end

    context "when message is sent without error but db delete does not work" do
      before do
        allow(Repo).to accept(:delete, fn(_) -> {:error, "my error"} end)
        allow(BotsUnit.MessagesProducers.TestMessageProducer).to accept(:log_warning, fn(_message) -> nil end)
        {:shared, result: MessageProducer.response(message.id, {:ok, :tuple}) }
      end
      it do: expect( shared.result ).to eq(:exit)
      xit do: expect( BotsUnit.MessagesProducers.TestMessageProducer ).to accepted(:log_warning, :any, count: 1)
      it do: expect( StoppedPartition |> Repo.all |> List.first |> Map.take([:topic, :partition, :message_id, :error]))
             .to eq(%{topic: "topic", partition: 1, message_id: message.id, error: "BotsUnit.MessagesProducers.Ecto unable to delete row #{message.id}\n\"my error\"\nproducer exited."})
    end

    context "when message is not sent" do
      let! :message, do: Repo.insert!(%EctoProducerMessage{topic: "topic2", partition: 3, blob: "blob123", inserted_at: t, updated_at: t})
      before do
        allow(MessageProducer).to accept(:log_warning, fn(_message) -> nil end)
        {:shared, result: MessageProducer.response(message.id, {:error, "an error"}) }
      end
      it do: expect( shared.result ).to eq(:exit)
      xit do: expect( MessageProducer ).to accepted(:log_warning, :any, count: 1)
      it do: expect( StoppedPartition |> Repo.all |> List.first |> Map.take([:topic, :partition, :message_id, :error]))
            .to eq(%{topic: "topic2", partition: 3, message_id: message.id, error: "BotsUnit.MessagesProducers.Ecto error while sending message #{message.id}\n\"an error\"\nproducer exited."})
    end

    context "when a middleware stop message sending" do
      let! :message, do: Repo.insert!(%EctoProducerMessage{topic: "topic23", partition: 5, blob: "blob987", inserted_at: t, updated_at: t})
      before do
        allow(MessageProducer).to accept(:log_warning, fn(_message) -> nil end)
        {:shared, result: MessageProducer.response(message.id, {:stop, "middleware", "middle_error"}) }
      end
      it do: expect( shared.result ).to eq(:exit)
      xit do: expect( MessageProducer ).to accepted(:log_warning, :any, count: 1)
      it do: expect( StoppedPartition |> Repo.all |> List.first |> Map.take([:topic, :partition, :message_id, :error]))
            .to eq(%{topic: "topic23", partition: 5, message_id: message.id, error: "BotsUnit.MessagesProducers.Ecto message #{message.id} delivery stopped by middleware middleware\n\"middle_error\"\nproducer exited."})
    end
  end
end