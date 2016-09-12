defmodule WokAsyncMessageHandler.MessagesHandlers.EctoSpec do
  use ESpec

  alias WokAsyncMessageHandler.Spec.Repo
  alias WokAsyncMessageHandler.Models.EctoProducerMessage
  alias WokAsyncMessageHandler.Models.StoppedPartition

  describe "#messages" do
    let! :t, do: Ecto.DateTime.utc
    let! :message1, do: Repo.insert!(%EctoProducerMessage{topic: "topic_1", partition: 1, blob: "blob1", inserted_at: t, updated_at: t})
    let! :message2, do: Repo.insert!(%EctoProducerMessage{topic: "topic_2", partition: 1, blob: "blob2", inserted_at: t, updated_at: t})
    let! :message3, do: Repo.insert!(%EctoProducerMessage{topic: "topic_1", partition: 1, blob: "blob3", inserted_at: t, updated_at: t})

    context "when message fetch is ok" do
      it do: expect(WokAsyncMessageHandler.MessagesHandlers.Ecto.messages "topic_1", 1, 1).to eq([{message1.id, "topic_1", 1, "blob1"}])
      it do: expect(WokAsyncMessageHandler.MessagesHandlers.Ecto.messages "topic_2", 1, 1000).to eq([{message2.id, "topic_2", 1, "blob2"}])
      it do: expect(WokAsyncMessageHandler.MessagesHandlers.Ecto.messages "topic_1", 1, 2).to eq([{message1.id, "topic_1", 1, "blob1"}, {message3.id, "topic_1", 1, "blob3"}])
    end

    context "when fetch is not ok" do
      before do: allow(Repo).to accept(:all, fn(_) -> raise "Repo.all : mock for fetch not ok" end)
      before do: allow(Exceptions).to accept(:throw_exception, fn(_exception, _data, :messages, false) -> nil end)
      before do: {:shared, messages: WokAsyncMessageHandler.MessagesHandlers.Ecto.messages("topic_987", 12, 34)}
      it do: expect(shared.messages).to eq([])
    end

    context "when ecto is not started" do
      before do: allow(Application).to accept(:ensure_started, fn(:ecto) -> {:error, :term} end)
      it do: expect(WokAsyncMessageHandler.MessagesHandlers.Ecto.messages "topic_1", 1, 1).to eq([])
    end
  end

  describe "#response" do
    let! :t, do: Ecto.DateTime.utc
    let! :message, do: Repo.insert!(%EctoProducerMessage{topic: "topic", partition: 1, blob: "blob", inserted_at: t, updated_at: t})
    before do: allow(WokAsyncMessageHandler.MessagesHandlers.Ecto).to accept(:log_warning, fn(_message) -> nil end)
    context "when message is sent without error" do
      before do
        {:shared, result: WokAsyncMessageHandler.MessagesHandlers.Ecto.response(message.id, {:ok, :ok}, false) }
      end
      it do: expect(shared.result ).to eq(:next)
      it do: expect(Repo.get(EctoProducerMessage, message.id) ).to eq(nil)
    end

    context "when message is sent without error but db delete does not work" do
      before do
        allow(Repo).to accept(:delete, fn(_) -> {:error, "my error"} end)
        {:shared, result: WokAsyncMessageHandler.MessagesHandlers.Ecto.response(message.id, {:ok, :tuple}, true) }
      end
      it do: expect(shared.result ).to eq(:exit)
      it do: expect(WokAsyncMessageHandler.MessagesHandlers.Ecto).to accepted(:log_warning, :any, count: 1)
      it do: expect(StoppedPartition |> Repo.all |> List.first |> Map.take([:topic, :partition, :message_id, :error]))
             .to eq(%{topic: "topic", partition: 1, message_id: message.id, error: "Elixir.WokAsyncMessageHandler.MessagesHandlers.Ecto unable to delete row #{message.id}\n\"my error\"\nproducer exited."})
    end

    context "when message is not sent" do
      let! :message, do: Repo.insert!(%EctoProducerMessage{topic: "topic2", partition: 3, blob: "blob123", inserted_at: t, updated_at: t})
      before do
        {:shared, result: WokAsyncMessageHandler.MessagesHandlers.Ecto.response(message.id, {:error, "an error"}, true) }
      end
      it do: expect(shared.result).to eq(:exit)
      it do: expect(WokAsyncMessageHandler.MessagesHandlers.Ecto).to accepted(:log_warning, :any, count: 1)
      it do: expect(StoppedPartition |> Repo.all |> List.first |> Map.take([:topic, :partition, :message_id, :error]))
            .to eq(%{topic: "topic2", partition: 3, message_id: message.id, error: "Elixir.WokAsyncMessageHandler.MessagesHandlers.Ecto error while sending message #{message.id}\n\"an error\"\nproducer exited."})
    end

    context "when a middleware stop message sending" do
      let! :message, do: Repo.insert!(%EctoProducerMessage{topic: "topic23", partition: 5, blob: "blob987", inserted_at: t, updated_at: t})
      before do
        {:shared, result: WokAsyncMessageHandler.MessagesHandlers.Ecto.response(message.id, {:stop, "middleware", "middle_error"}, true) }
      end
      it do: expect(shared.result ).to eq(:exit)
      it do: expect(WokAsyncMessageHandler.MessagesHandlers.Ecto).to accepted(:log_warning, :any, count: 1)
      it do: expect(StoppedPartition |> Repo.all |> List.first |> Map.take([:topic, :partition, :message_id, :error]))
            .to eq(%{topic: "topic23", partition: 5, message_id: message.id, error: "Elixir.WokAsyncMessageHandler.MessagesHandlers.Ecto message #{message.id} delivery stopped by middleware middleware\n\"middle_error\"\nproducer exited."})
    end
  end
end