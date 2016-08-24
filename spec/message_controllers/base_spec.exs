defmodule WokAsyncMessageHandler.MessageControllers.BaseSpec do
  use ESpec, async: false
  alias WokAsyncMessageHandler.Repo
  alias WokAsyncMessageHandler.Models.ConsumerMessageIndex
  alias WokAsyncMessageHandler.Models.StoppedPartition

  before do
    if( :ets.info(BotsUnit.MessageControllers.Base.Helpers.ets_table) == :undefined ) do
      :ets.new(BotsUnit.MessageControllers.Base.Helpers.ets_table, [:set, :public, :named_table])
    end
  end

  describe "#update", update: true do
    let :event, do: {:message_transfert, "",
                               {:wok_msg,
                                {:message, "978202ae-ac5e-4093-97d6-951658616680",
                                 ["bot/resource/updated"], "bot", %{},
                                 %{binary_body: true, compress: true, message_id: 400},
                                 "[{\"version\":1,\"payload\":{\"id\":12, \"error\":\"new error\"}}]"},
                                {:wok_msg_resp, false, :undefined, :undefined, :undefined, ""}, [],
                                :undefined, :undefined}, 1, "bots_events", "bot/resource/updated",
                               {MyBot.MessageControllers.ResourcessController, :update},
                               :my_bot_queue_bots_events_0,
                               :"7779989aaf80690ae4f9ee175264ee356e1c2cfeb3e4b5d70973172465f37755",
                               :one_for_one,
                               "g2gEZ2QADW5vbm9kZUBub2hvc3QAAAL4AAAAAABtAAAAC2JvdHNfZXZlbnRzYQBhMA=="}

    let :event_without_id, do: {:message_transfert, "",
                               {:wok_msg,
                                {:message, "978202ae-ac5e-4093-97d6-951658616680",
                                 ["bot/resource/updated"], "bot", %{},
                                 %{binary_body: true, compress: true, message_id: 401},
                                 "[{\"version\":1,\"payload\":{\"id\":12, \"topic\":\"topic bidon\", \"partition\":\"87687\", \"message_id\":\"1224\", \"error\":\"new error\"}}]"},
                                {:wok_msg_resp, false, :undefined, :undefined, :undefined, ""}, [],
                                :undefined, :undefined}, 1, "bots_events", "bot/resource/updated",
                               {MyBot.MessageControllers.ResourcessController, :update},
                               :my_bot_queue_bots_events_0,
                               :"7779989aaf80690ae4f9ee175264ee356e1c2cfeb3e4b5d70973172465f37755",
                               :one_for_one,
                               "g2gEZ2QADW5vbm9kZUBub2hvc3QAAAL4AAAAAABtAAAAC2JvdHNfZXZlbnRzYQBhMA=="}

    context "when message has already been processed" do
      before do: allow(Repo).to accept(:get, fn(module, id) ->
          case module do
            ConsumerMessageIndex -> passthrough([module, id])
            StoppedPartition -> nil
          end
        end)
      context "with id_message fetched in DB" do
        let :event1, do: {:message_transfert, "",
                               {:wok_msg,
                                {:message, "978202ae-ac5e-4093-97d6-951658616680",
                                 ["bot/resource/updated"], "bot", %{},
                                 %{binary_body: true, compress: true, message_id: 401},
                                 "[{\"version\":1,\"payload\":{\"id\":12, \"topic\":\"topic bidon\", \"partition\":\"87687\", \"message_id\":\"1224\", \"error\":\"new error\"}}]"},
                                {:wok_msg_resp, false, :undefined, :undefined, :undefined, ""}, [],
                                :undefined, :undefined}, 200, "bots_events", "bot/resource/updated",
                               {MyBot.MessageControllers.ResourcessController, :update},
                               :my_bot_queue_bots_events_0,
                               :"7779989aaf80690ae4f9ee175264ee356e1c2cfeb3e4b5d70973172465f37755",
                               :one_for_one,
                               "g2gEZ2QADW5vbm9kZUBub2hvc3QAAAL4AAAAAABtAAAAC2JvdHNfZXZlbnRzYQBhMA=="}
        before do
          cmi = Repo.insert!(%ConsumerMessageIndex{topic: "bots_events", partition: 200, id_message: 401})
          {:shared, result: TestMessageController.update(event1), cmi: cmi}
        end
        it do: expect(shared.result).to eq(event1)
        it do: expect(Repo.get(ConsumerMessageIndex, shared.cmi.id).id_message).to eq(401)
        it do: expect(Repo).to accepted(:get, [StoppedPartition, 12], count: 0)
      end

      context "with id_message already in ets" do
        let! :cmi, do: Repo.insert!(%ConsumerMessageIndex{topic: "bots_events", partition: 1, id_message: 551})
        before do: allow(Repo).to accept(:one, fn(arg) -> passthrough([arg]) end)
        before do
          true = :ets.insert(:botsunit_wok_consumers_message_index, {"bots_events_1", cmi})
          {:shared, result: TestMessageController.update(event)}
        end

        it do: expect(shared.result).to eq(event)
        it do: expect(Repo.get(ConsumerMessageIndex, cmi.id).id_message).to eq(551)
        it do: expect(Repo).to accepted(:one, :any, count: 0)
        it do: expect(Repo).to accepted(:get, [StoppedPartition, 12], count: 0)
      end
    end

    context "when message has not yet been processed" do
      context "with id_message already in ets" do
        let! :cmi, do: Repo.insert!(%ConsumerMessageIndex{topic: "bots_events", partition: 1, id_message: 399})
        before do: true = :ets.insert(:botsunit_wok_consumers_message_index, {"bots_events_1", cmi})

        context "payload id does not match with a resource id" do
          before do: allow(TestMessageController).to accept(:test_on_update_before_update)
          before do: allow(TestMessageController).to accept(:test_on_update_after_update)

          context "when insert in db is ok" do
            before do: {:shared, result: TestMessageController.update(event_without_id)}
            it do: expect(shared.result).to eq(event_without_id)
            it do: expect(ConsumerMessageIndex |> Repo.all |> Enum.count).to eq(1)
            it do: expect(StoppedPartition |> Repo.all |> Enum.count).to eq(1)
            it do: expect(StoppedPartition |> Repo.all |> List.first |> Map.take([:topic, :paritition, :message_id, :error]))
                   .to eq(%{error: "new error", message_id: 1224, topic: "topic bidon"})
            it do: expect(TestMessageController).to accepted(:test_on_update_before_update, :any, count: 1)
            it do: expect(TestMessageController).to accepted(:test_on_update_after_update, :any, count: 1)
            it do: expect(Repo.get(ConsumerMessageIndex, cmi.id).id_message).to eq(401)
            it do: expect(:ets.lookup(:botsunit_wok_consumers_message_index, "bots_events_1"))
                     .to eq([{"bots_events_1", Repo.get(ConsumerMessageIndex, cmi.id)}])
          end
          context "when error on insert in db" do
            before do: allow(Repo).to accept(:insert_or_update, fn(_) -> {:error, :ecto_changeset} end)
            before do
              exception = try do
                TestMessageController.update(event_without_id)
              rescue
                e -> e
              end
              {:shared, exception: exception}
            end

            it do: expect(ConsumerMessageIndex |> Repo.all |> Enum.count).to eq(1)
            it do: expect(StoppedPartition |> Repo.all |> Enum.count).to eq(0)
            it do: expect(TestMessageController).to accepted(:test_on_update_before_update, :any, count: 1)
            it do: expect(TestMessageController).to accepted(:test_on_update_after_update, :any, count: 0)
            it do: expect(Repo.get(ConsumerMessageIndex, cmi.id).id_message).to eq(399)
            it do: expect(:ets.lookup(:botsunit_wok_consumers_message_index, "bots_events_1"))
                   .to eq([{"bots_events_1", Repo.get(ConsumerMessageIndex, cmi.id)}])
            it do: expect(String.match?(shared.exception.message, ~r/Wok Async Message Handler Exception @update$/))
          end

          context "when update_consumer_message_index fails" do
            before do
              changeset = ConsumerMessageIndex.changeset(cmi, %{id_message: 99999})
              allow(ConsumerMessageIndex).to accept(:changeset, fn(_cmi, %{id_message: 401}) -> changeset end)
              allow(Repo).to accept(:update, fn(changeset) -> {:error, changeset} end)
              exception = try do
                TestMessageController.update(event_without_id)
              rescue
                e -> e
              end
              {:shared, changeset: changeset, exception: exception, fresh_cmi: Repo.get(ConsumerMessageIndex, cmi.id)}
            end              
            it do: expect(StoppedPartition |> Repo.all |> Enum.count ).to eq(0)
            it do: expect(shared.fresh_cmi.id_message).to eq(399)
            it do: expect(:ets.lookup(:botsunit_wok_consumers_message_index, "bots_events_1"))
                   .to eq([{"bots_events_1", shared.fresh_cmi}])
            it do: expect(String.match?(shared.exception.message, ~r/Wok Async Message Handler Exception @update$/))
          end
        end
      end
    end
  end







  describe "#destroy" do
    let :event, do: {:message_transfert, "",
                               {:wok_msg,
                                {:message, "978202ae-ac5e-4093-97d6-951658616680",
                                 ["identity/ticket/destroyed"], "identity", %{},
                                 %{binary_body: true, compress: true, message_id: 551},
                                 "[{\"version\":1,\"payload\":{\"id\":12}}]"},
                                {:wok_msg_resp, false, :undefined, :undefined, :undefined, ""}, [],
                                :undefined, :undefined}, 0, "bots_events", "identity/ticket/destroyed",
                               {BoobNotification.MessageControllers.TicketsController, :destroy},
                               :boob_notification_queue_bots_events_0,
                               :"7779989aaf80690ae4f9ee175264ee356e1c2cfeb3e4b5d70973172465f37755",
                               :one_for_one,
                               "g2gEZ2QADW5vbm9kZUBub2hvc3QAAAL4AAAAAABtAAAAC2JvdHNfZXZlbnRzYQBhMA=="}

    context "when message has already been processed" do
      before do: allow(Repo).to accept(:get, fn(module, id) ->
          case module do
            ConsumerMessageIndex -> passthrough([module, id])
            StoppedPartition -> nil
          end
        end)
      context "with id_message fetched in DB" do
        let :event1, do: {:message_transfert, "",
                               {:wok_msg,
                                {:message, "978202ae-ac5e-4093-97d6-951658616680",
                                 ["identity/ticket/destroyed"], "identity", %{},
                                 %{binary_body: true, compress: true, message_id: 551},
                                 "[{\"version\":1,\"payload\":{\"id\":12}}]"},
                                {:wok_msg_resp, false, :undefined, :undefined, :undefined, ""}, [],
                                :undefined, :undefined}, 356, "bots_events", "identity/ticket/destroyed",
                               {BoobNotification.MessageControllers.TicketsController, :destroy},
                               :boob_notification_queue_bots_events_0,
                               :"7779989aaf80690ae4f9ee175264ee356e1c2cfeb3e4b5d70973172465f37755",
                               :one_for_one,
                               "g2gEZ2QADW5vbm9kZUBub2hvc3QAAAL4AAAAAABtAAAAC2JvdHNfZXZlbnRzYQBhMA=="}
        let! :cmi, do: Repo.insert!(%ConsumerMessageIndex{topic: "bots_events", partition: 356, id_message: 560})
        before do: {:shared, result: TestMessageController.destroy(event1)}

        it do: expect(shared.result).to eq(event1)
        it do: expect(Repo.get(ConsumerMessageIndex, cmi.id).id_message).to eq(560)
        it do: expect(Repo).to accepted(:get, [StoppedPartition, 12], count: 0)
      end

      context "with id_message already in ets" do
        let! :cmi, do: Repo.insert!(%ConsumerMessageIndex{topic: "bots_events", partition: 0, id_message: 560})
        before do
          allow(Repo).to accept(:one)
          true = :ets.insert(:botsunit_wok_consumers_message_index, {"bots_events_0", cmi})
          {:shared, result: TestMessageController.destroy(event)}
        end
        it do: expect(shared.result).to eq(event)
        it do: expect(Repo.get(ConsumerMessageIndex, cmi.id).id_message).to eq(560)
        it do: expect(Repo).to accepted(:one, :any, count: 0)
        it do: expect(Repo).to accepted(:get, [StoppedPartition, 12], count: 0)
      end
    end

    context "when message has not yet been processed" do
      context "with id_message already in ets" do
        let! :cmi, do: Repo.insert!(%ConsumerMessageIndex{topic: "bots_events", partition: 0, id_message: 550})
        before do
          allow(Repo).to accept(:one)
          true = :ets.insert(:botsunit_wok_consumers_message_index, {"bots_events_0", cmi})
        end

        context "payload id does not match with a resource id" do
          before do
            allow(Repo).to accept(:delete)
            {:shared, result: TestMessageController.destroy(event)}
          end
          it do: expect(shared.result).to eq(event)
          it do: expect(Repo.get(ConsumerMessageIndex, cmi.id).id_message).to eq(551)
          it do: expect(ConsumerMessageIndex |> Repo.all |> Enum.count).to eq(1)
          it do: expect(Repo).to accepted(:one, :any, count: 0)
          it do: expect(Repo).to accepted(:delete, :any, count: 0)
        end

        context "when payload id matches with a resource id" do
          let! :resource, do: Repo.insert!(%StoppedPartition{topic: "my_topic", partition: 12, message_id: 9999, error: "no_error..."})
          let :event, do: {:message_transfert, "",
                               {:wok_msg,
                                {:message, "978202ae-ac5e-4093-97d6-951658616680",
                                 ["bot/stopped_partition/destroyed"], "identity", %{},
                                 %{binary_body: true, compress: true, message_id: 551},
                                 "[{\"version\":1,\"payload\":{\"id\":#{resource.id}}}]"},
                                {:wok_msg_resp, false, :undefined, :undefined, :undefined, ""}, [],
                                :undefined, :undefined}, 0, "bots_events", "bot/stopped_partition/destroyed",
                               {BoobNotification.MessageControllers.TicketsController, :destroy},
                               :boob_notification_queue_bots_events_0,
                               :"7779989aaf80690ae4f9ee175264ee356e1c2cfeb3e4b5d70973172465f37755",
                               :one_for_one,
                               "g2gEZ2QADW5vbm9kZUBub2hvc3QAAAL4AAAAAABtAAAAC2JvdHNfZXZlbnRzYQBhMA=="}
          context "when the whole transaction is ok" do
            before do
              allow(TestMessageController).to accept(:test_callback)
              {:shared, result: TestMessageController.destroy(event)}
            end
            it do: expect(shared.result).to eq(event)
            it do: expect(ConsumerMessageIndex |> Repo.all |> Enum.count).to eq(1)
            it do: expect(Repo).to accepted(:one, :any, count: 0)
            it do: expect(StoppedPartition |> Repo.all |> Enum.count ).to eq(0)
            it do: expect(TestMessageController).to accepted(:test_callback, :any, count: 1)
            it do: expect(Repo.get(ConsumerMessageIndex, cmi.id).id_message).to eq(551)
            it do: expect(:ets.lookup(:botsunit_wok_consumers_message_index, "bots_events_0"))
                   .to eq([{"bots_events_0", Repo.get(ConsumerMessageIndex, cmi.id)}])
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
            it do: expect(shared.fresh_cmi.id_message).to eq(550)
            it do: expect(TestMessageController).to accepted(:test_callback, :any, count: 0)
            it do: expect(:ets.lookup(:botsunit_wok_consumers_message_index, "bots_events_0"))
                    .to eq([{"bots_events_0", shared.fresh_cmi}])
            it do: expect(String.match?(shared.exception.message, ~r/Wok Async Message Handler Exception @destroy$/))
          end

          context "when update_consumer_message_index fails" do
            before do
              changeset = ConsumerMessageIndex.changeset(cmi, %{id_message: 99999})
              allow(ConsumerMessageIndex).to accept(:changeset, fn(_cmi, %{id_message: 551}) -> changeset end)
              allow(Repo).to accept(:update, fn(changeset) -> {:error, changeset} end)
              exception = try do
                TestMessageController.destroy(event)
              rescue
                e -> e
              end
              {:shared, exception: exception, fresh_cmi: Repo.get(ConsumerMessageIndex, cmi.id)}
            end
            it do: expect(StoppedPartition |> Repo.all |> Enum.count ).to eq(1)
            it do: expect(shared.fresh_cmi.id_message).to eq(550)
            it do: expect(:ets.lookup(:botsunit_wok_consumers_message_index, "bots_events_0"))
                   .to eq([{"bots_events_0", shared.fresh_cmi}])
            it do: expect(String.match?(shared.exception.message, ~r/Wok Async Message Handler Exception @destroy$/))
          end
        end
      end
    end
  end
end
