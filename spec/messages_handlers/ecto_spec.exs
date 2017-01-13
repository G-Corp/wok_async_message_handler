defmodule WokAsyncMessageHandler.MessagesHandlers.EctoSpec do
  use ESpec

  alias WokAsyncMessageHandler.Spec.Repo
  alias WokAsyncMessageHandler.Models.EctoProducerMessage

  before do: allow(described_module).to accept(:log_warning, fn(_message) -> nil end)

  describe "#messages" do
    let! :t, do: Ecto.DateTime.utc
    let! :message1, do: Repo.insert!(%EctoProducerMessage{topic: "topic_1", partition: 1, blob: "blob1", inserted_at: t, updated_at: t})
    let! :message2, do: Repo.insert!(%EctoProducerMessage{topic: "topic_2", partition: 1, blob: "blob2", inserted_at: t, updated_at: t})
    let! :message3, do: Repo.insert!(%EctoProducerMessage{topic: "topic_1", partition: 1, blob: "blob3", inserted_at: t, updated_at: t})
    let! :message4, do: Repo.insert!(%EctoProducerMessage{topic: "topic_1", partition: 2, blob: "blob4", inserted_at: t, updated_at: t})

    context "when message fetch is ok" do
      it do: expect(described_module.messages [{"topic_1", [1]}], 1).to eq([{message1.id, "topic_1", 1, "blob1"}])
      it do: expect(described_module.messages [{"topic_2", [1]}], 1000).to eq([{message2.id, "topic_2", 1, "blob2"}])
      it do: expect(Enum.sort(described_module.messages [{"topic_1", [1]}], 2)).to eq(Enum.sort([{message1.id, "topic_1", 1, "blob1"}, {message3.id, "topic_1", 1, "blob3"}]))
      it do: expect(Enum.sort(described_module.messages [{"topic_1", [1, 2]}, {"topic_2", [1]}], 4)).to have_length(4)
    end

    context "when fetch is not ok" do
      before do: allow(Repo).to accept(:all, fn(_) -> raise "Repo.all : mock for fetch not ok" end)
      before do: allow(Exceptions).to accept(:throw_exception, fn(_exception, _data, :messages, false) -> nil end)
      before do: {:shared, messages: described_module.messages([{"topic_987", [12]}], 34)}
      it do: expect(shared.messages).to eq([])
    end

    context "when ecto is not started" do
      before do: allow(Application).to accept(:ensure_started, fn(:ecto) -> {:error, :term} end)
      it do: expect(described_module.messages [{"topic_1", [1]}], 1).to eq([])
    end
  end

  describe "#response" do
    let! :t, do: Ecto.DateTime.utc
    let! :message, do: Repo.insert!(%EctoProducerMessage{topic: "topic", partition: 1, blob: "blob", inserted_at: t, updated_at: t})

    context "when message is sent without error" do
      before do
        {:shared, result: described_module.response([message.id], [])}
      end
      it do: expect(shared.result).to eq(:ok)
      it do: expect(Repo.get(EctoProducerMessage, message.id)).to eq(nil)
    end

    context "when message is sent without error but db delete does not work" do
      before do: allow(Repo).to accept(:delete_all, fn(_) -> raise(RuntimeError, "db failure") end)
      before do
        {:shared, result: described_module.response([message.id], [])}
      end

      it do: expect(shared.result).to eq(:ok)
      it do: expect(described_module).to accepted(:log_warning, :any, count: 1)
    end

    context "when message is not sent" do
      let! :message, do: Repo.insert!(%EctoProducerMessage{topic: "topic2", partition: 3, blob: "blob123", inserted_at: t, updated_at: t})
      before do
        {:shared, result: described_module.response([], [message.id]) }
      end
      it do: expect(shared.result).to eq(:ok)
      it do: expect(described_module).to accepted(:log_warning, :any, count: 1)
    end
  end
end
