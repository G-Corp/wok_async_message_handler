defmodule WokAsyncMessageHandler.MessagesEnqueuers.EctoSpec do
  use ESpec

  alias WokAsyncMessageHandler.Spec.Repo
  alias WokAsyncMessageHandler.MessagesEnqueuers.DummyEnqueuer

  describe "#enqueue_rtmessage" do
    let :fake_struct, do: %{__struct__: TestEctoSchema, id: "fake_idrt"}
    before do: allow(:kafe).to accept(:partitions, fn(_) -> [0, 1, 2] end)

    context "when no error" do
      before do
        allow(Repo).to accept(:insert, fn(fake_struct) -> {:ok, fake_struct} end )
        {:ok, message} = DummyEnqueuer.enqueue_rtmessage(%{session_id: "my_session_id"})
        {:shared, message: message}
      end
     it do: expect(Repo).to accepted(:insert, :any, count: 1)
     it do: expect(shared.message.partition).to eq(1)
     it do: expect(shared.message.topic).to eq("realtime_topic")
     it do: expect(shared.message.blob)
            .to eq(
              Wok.Message.encode_message(
                {"realtime_topic", "my_session_id"},
                "from_bot",
                "from_bot/real_time/notify",
                "[{\"version\":1,\"payload\":{\"source\":\"from_bot\",\"session_id\":\"my_session_id\"}}]"
              )
              |> elem(3)
            )
    end

    context "when storage error" do
      before do: allow(Repo).to accept(:insert, fn(_fake_struct) -> {:error, "storage error"} end )
      it do: {:error, "storage error"} = DummyEnqueuer.enqueue_rtmessage(%{session_id: "my_session_id"})
    end

    context "when wok message error" do
      before do: allow(Wok.Message).to accept(:encode_message, fn(_, _, _, _) -> {:error, "wok message error"} end )
      it do: {:error, "wok message error"} = DummyEnqueuer.enqueue_rtmessage(%{session_id: "my_session_id"})
    end

    context "with options" do
      before do
        allow(Repo).to accept(:insert, fn(fake_struct) -> {:ok, fake_struct} end )
        {:ok, message} = DummyEnqueuer.enqueue_rtmessage(
          %{session_id: "my_session_id", data_for_pkey: "123", source: "my_source"},
          [pkey: :data_for_pkey, from: "my_from", to: "my_to"]
        )
        {:shared, message: message}
      end
      it do: expect(Repo).to accepted(:insert, :any, count: 1)
      it do: expect(shared.message.partition).to eq(1)
      it do: expect(shared.message.topic).to eq("realtime_topic")
      it do: expect(shared.message.blob)
            .to eq(
              Wok.Message.encode_message(
                                          {"realtime_topic", "123"},
                                          "my_from",
                                          "my_to",
                                          "[{\"version\":1,\"payload\":{\"source\":\"my_source\",\"session_id\":\"my_session_id\",\"data_for_pkey\":\"123\"}}]"
                                          ) |> elem(3)
                                        )
    end
  end

  describe "#enqueue_message" do
    let :fake_struct, do: %{__struct__: TestEctoSchema, id: "fake_id1"}
    before do: allow(:kafe).to accept(:partitions, fn(_) -> [0, 1] end)

    context "when no error" do
      before do
        allow(Repo).to accept(:insert, fn(fake_struct) -> {:ok, fake_struct} end )
        {:ok, message} = DummyEnqueuer.enqueue_message(fake_struct, :created)
        {:shared, message: message}
      end
     it do: expect(Repo).to accepted(:insert, :any, count: 1)
     it do: expect(shared.message.partition).to eq(1)
     it do: expect(shared.message.topic).to eq("messages_topic")
     it do: expect(shared.message.blob)
            .to eq(
              Wok.Message.encode_message(
                                          {"messages_topic", "fake_id1"},
                                          "from_bot",
                                          "bot/resource/created",
                                          "[{\"version\":1,\"payload\":{\"id\":\"fake_id1\"}}]"
                                          ) |> elem(3)
                                        )
    end

    context "when storage error" do
      before do: allow(Repo).to accept(:insert, fn(_fake_struct) -> {:error, "storage error"} end )
      it do: {:error, "storage error"} = DummyEnqueuer.enqueue_message(fake_struct, :created)
    end

    context "when wok message error" do
      before do: allow(Wok.Message).to accept(:encode_message, fn(_, _, _, _) -> {:error, "wok message error"} end )
      it do: {:error, "wok message error"} = DummyEnqueuer.enqueue_message(fake_struct, :created)
    end

    context "with custom topic and metadata" do
      before do
        allow(Repo).to accept(:insert, fn(fake_struct) -> {:ok, fake_struct} end )
        {:ok, message} = DummyEnqueuer.enqueue_message(
                          fake_struct, 
                          :created, 
                          [metadata: %{key: :value}, topic: "blablatopic"]
                        )
        {:shared, message: message}
      end
     it do: expect(Repo).to accepted(:insert, :any, count: 1)
     it do: expect(shared.message.partition).to eq(1)
     it do: expect(shared.message.topic).to eq("blablatopic")
     it do: expect(shared.message.blob)
            .to eq(
              Wok.Message.encode_message(
                                          {"blablatopic", "fake_id1"},
                                          "from_bot",
                                          "bot/resource/created",
                                          "[{\"version\":1,\"payload\":{\"id\":\"fake_id1\"},\"metadata\":{\"key\":\"value\"}}]"
                                          ) |> elem(3)
                                        )
    end
  end

  describe "#enqueue" do
    let :fake_struct, do: %{__struct__: TestEctoSchema, id: "fake_id"}
    before do: allow(:kafe).to accept(:partitions, fn(_) -> [0, 1] end)

    context "when no error" do
      before do
        allow(Repo).to accept(:insert, fn(fake_struct) -> {:ok, fake_struct} end )
        {:ok, message} = DummyEnqueuer.enqueue({"my_topic", "fake_id"}, "from_bot", "bot/resource/created", %{id: "fake_id"})
        {:shared, message: message}
      end
     it do: expect(Repo).to accepted(:insert, :any, count: 1)
     it do: expect(shared.message.partition).to eq(1)
     it do: expect(shared.message.topic).to eq("my_topic")
     it do: expect(shared.message.blob)
            .to eq(
              Wok.Message.encode_message(
                                          {"my_topic", "fake_id"},
                                          "from_bot",
                                          "bot/resource/created",
                                          "{\"id\":\"fake_id\"}"
                                          ) |> elem(3)
                                        )
    end

    context "when storage error" do
      before do: allow(Repo).to accept(:insert, fn(_fake_struct) -> {:error, "storage error"} end )
      it do: {:error, "storage error"} = DummyEnqueuer.enqueue({"my_topic", "fake_id"}, "from_bot", "bot/resource/created", %{id: "fake_id"})
    end

    context "when wok message error" do
      before do: allow(Wok.Message).to accept(:encode_message, fn(_, _, _, _) -> {:error, "wok message error"} end )
      it do: {:error, "wok message error"} = DummyEnqueuer.enqueue({"my_topic", "fake_id"}, "from_bot", "bot/resource/created", %{id: "fake_id"})
    end
  end
end