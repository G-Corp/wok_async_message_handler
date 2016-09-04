defmodule WokAsyncMessageHandler.MessageControllers.Base.DestroySpec do
  use ESpec, async: false
  alias WokAsyncMessageHandler.Spec.Repo
  alias WokAsyncMessageHandler.Models.ConsumerMessageIndex
  alias WokAsyncMessageHandler.Models.StoppedPartition
  alias WokAsyncMessageHandler.MessageControllers.Base.Helpers
  alias WokAsyncMessageHandler.Helpers.TestMessage

  before do
    if( :ets.info(Helpers.ets_table) == :undefined ) do
      :ets.new(Helpers.ets_table, [:set, :public, :named_table])
    end
  end

  describe "#destroy" do
    let! :from_bot, do: "from_bot"
    let! :cmi, do: Repo.insert!(%ConsumerMessageIndex{from: from_bot, id_message: 10})
    let! :resource_to_delete, do: Repo.insert!(%StoppedPartition{topic: "my_topic", partition: 12, message_id: 9999, error: "no_error..."})
    let! :payload, do: %{id: resource_to_delete.id}
    
    context "when message has already been processed" do
      let! :event, do: TestMessage.build_event_message(payload, from_bot, 10)
      before do: allow(Repo).to accept(:get, fn(module, id) ->
          case module do
            ConsumerMessageIndex -> passthrough([module, id])
            StoppedPartition -> nil
          end
        end)
      context "with id_message fetched in DB" do
        before do: {:shared, result: TestMessageController.destroy(event)}

        it do: expect(StoppedPartition |> Repo.all |> Enum.count ).to eq(1)
        it do: expect(shared.result).to eq(event)
        it do: expect(Repo.get(ConsumerMessageIndex, cmi.id).id_message).to eq(10)
        it do: expect(Repo).to accepted(:get, [StoppedPartition, 12], count: 0)
      end

      context "with id_message already in ets" do
        before do: allow(Repo).to accept(:one)
        before do: true = :ets.insert(:botsunit_wok_consumers_message_index, {from_bot, cmi})
        before do
          {:shared, result: TestMessageController.destroy(event)}
        end
        it do: expect(StoppedPartition |> Repo.all |> Enum.count ).to eq(1)
        it do: expect(shared.result).to eq(event)
        it do: expect(Repo.get(ConsumerMessageIndex, cmi.id).id_message).to eq(10)
        it do: expect(Repo).to accepted(:one, :any, count: 0)
        it do: expect(Repo).to accepted(:get, [StoppedPartition, 12], count: 0)
      end
    end

    context "when message has not yet been processed" do
      context "with id_message already in ets" do
        before do: allow(Repo).to accept(:one)
        before do: true = :ets.insert(:botsunit_wok_consumers_message_index, {from_bot, cmi})

        context "payload id does not match with a resource id" do
          let! :payload, do: %{id: 12345}
          let! :event, do: TestMessage.build_event_message(payload, from_bot, 11)
          before do
            allow(Repo).to accept(:delete)
            {:shared, result: TestMessageController.destroy(event)}
          end
          it do: expect(shared.result).to eq(event)
          it do: expect(Repo.get(ConsumerMessageIndex, cmi.id).id_message).to eq(11)
          it do: expect(ConsumerMessageIndex |> Repo.all |> Enum.count).to eq(1)
          it do: expect(Repo).to accepted(:one, :any, count: 0)
          it do: expect(Repo).to accepted(:delete, :any, count: 0)
        end

        context "when payload id matches with a resource id" do
          context "when the whole transaction is ok" do
            let! :event, do: TestMessage.build_event_message(payload, from_bot, 11)
            before do
              allow(TestMessageController).to accept(:test_callback)
              {:shared, result: TestMessageController.destroy(event)}
            end
            it do: expect(shared.result).to eq(event)
            it do: expect(ConsumerMessageIndex |> Repo.all |> Enum.count).to eq(1)
            it do: expect(Repo).to accepted(:one, :any, count: 0)
            it do: expect(StoppedPartition |> Repo.all |> Enum.count ).to eq(0)
            it do: expect(TestMessageController).to accepted(:test_callback, :any, count: 1)
            it do: expect(Repo.get(ConsumerMessageIndex, cmi.id).id_message).to eq(11)
            it do: expect(:ets.lookup(:botsunit_wok_consumers_message_index, from_bot))
                   .to eq([{from_bot, Repo.get(ConsumerMessageIndex, cmi.id)}])
          end

          context "when using another field as id to find the message" do
            let! :payload, do: %{id: 87686586, pmessage_id: 9999}
            let! :event, do: TestMessage.build_event_message(payload, from_bot, 11)
            before do: {:shared, result: TestMessageControllerWithMasterKey.destroy(event)}
            it do: expect(shared.result).to eq(event)
            it do: expect(ConsumerMessageIndex |> Repo.all |> Enum.count).to eq(1)
            it do: expect(Repo).to accepted(:one, :any, count: 0)
            it do: expect(StoppedPartition |> Repo.all |> Enum.count ).to eq(0)
            it do: expect(Repo.get(ConsumerMessageIndex, cmi.id).id_message).to eq(11)
            it do: expect(:ets.lookup(:botsunit_wok_consumers_message_index, from_bot))
                   .to eq([{from_bot, Repo.get(ConsumerMessageIndex, cmi.id)}])
          end

          context "when delete fails" do
            before do
              allow(TestMessageController).to accept(:test_callback)
              allow(Repo).to accept(:delete, fn(_) -> {:error, :ecto_changeset} end)
              exception = try do
                TestMessageController.destroy(event)
              rescue
                e -> e
              end
              {:shared, exception: exception, fresh_cmi: Repo.get(ConsumerMessageIndex, cmi.id)}
            end

            it do: expect(StoppedPartition |> Repo.all |> Enum.count ).to eq(1)
            it do: expect(shared.fresh_cmi.id_message).to eq(10)
            it do: expect(TestMessageController).to accepted(:test_callback, :any, count: 0)
            it do: expect(:ets.lookup(:botsunit_wok_consumers_message_index, from_bot))
                    .to eq([{from_bot, shared.fresh_cmi}])
            it do: expect(String.match?(shared.exception.message, ~r/Wok Async Message Handler Exception @destroy$/))
          end

          context "when update_consumer_message_index fails" do
            before do
              changeset = ConsumerMessageIndex.changeset(cmi, %{id_message: 99999})
              allow(ConsumerMessageIndex).to accept(:changeset, fn(_cmi, %{id_message: 11}) -> changeset end)
              allow(Repo).to accept(:update, fn(changeset) -> {:error, changeset} end)
              exception = try do
                TestMessageController.destroy(event)
              rescue
                e -> e
              end
              {:shared, exception: exception, fresh_cmi: Repo.get(ConsumerMessageIndex, cmi.id)}
            end
            it do: expect(StoppedPartition |> Repo.all |> Enum.count ).to eq(1)
            it do: expect(shared.fresh_cmi.id_message).to eq(10)
            it do: expect(:ets.lookup(:botsunit_wok_consumers_message_index, from_bot))
                   .to eq([{from_bot, shared.fresh_cmi}])
            it do: expect(String.match?(shared.exception.message, ~r/Wok Async Message Handler Exception @destroy$/))
          end
        end
      end
    end
  end
end
