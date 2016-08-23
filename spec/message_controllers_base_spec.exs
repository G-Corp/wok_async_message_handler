defmodule WokAsyncMessageHandler.MessageControllersBaseSpec do
  use ESpec, async: false
  alias WokAsyncMessageHandler.Repo
  alias WokAsyncMessageHandler.Models.ConsumerMessageIndex
  alias WokAsyncMessageHandler.Models.StoppedPartition

  before do
    if( :ets.info(BotsUnit.MessageControllers.Base.Helpers.ets_table) == :undefined ) do
      :ets.new(BotsUnit.MessageControllers.Base.Helpers.ets_table, [:set, :public, :named_table])
    end
  end

  describe "#destroy" do
    let :event_created, do: {
                              :message_transfert, 
                              "",
                              {:wok_msg,
                                {:message, 
                                  "4d106455-c16c-49fc-b19f-71dad21e501a",
                                  ["identity/ticket/created"],
                                  "identity", 
                                  %{},
                                  %{binary_body: true, compress: true, message_id: 549},
                                  "[{\"version\":1,\"payload\":{id: 12, \"topic\":\"0e437016-f67b-4676-b2ca-820238fdbc00\",\"partition\":99999,\"message_id\":123}}]"
                                },
                                {:wok_msg_resp, false, :undefined, :undefined, :undefined, ""},
                                [],
                                :undefined,
                                :undefined
                              },
                              0, 
                              "bots_events", 
                              "identity/ticket/created",
                              {BoobNotification.MessageControllers.TicketsController, :create},
                              :boob_notification_queue_bots_events_0,
                              :"7779989aaf80690ae4f9ee175264ee356e1c2cfeb3e4b5d70973172465f37755",
                              :one_for_one,
                              "g2gEZ2QADW5vbm9kZUBub2hvc3QAAAL2AAAAAABtAAAAC2JvdHNfZXZlbnRzYQBhLg=="
                            }
    let :event_destroyed, do: {:message_transfert, "",
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
        let! :cmi, do: Repo.insert!(%ConsumerMessageIndex{topic: "bots_events", partition: 0, id_message: 560})
        before do
          {:shared, result: TestMessageController.destroy(event_destroyed)}
        end
        it do: expect(shared.result).to eq(event_destroyed)
        it do: expect(Repo.get(ConsumerMessageIndex, cmi.id).id_message).to eq(560)
        it do: expect(Repo).to accepted(:get, [StoppedPartition, 12], count: 0)
      end

      context "with id_message already in ets" do
        let! :cmi, do: Repo.insert!(%ConsumerMessageIndex{topic: "bots_events", partition: 0, id_message: 560})
        before do
          allow(Repo).to accept(:one)
          true = :ets.insert(:botsunit_wok_consumers_message_index, {"bots_events_0", cmi})
          {:shared, result: TestMessageController.destroy(event_destroyed)}
        end
        it do: expect(shared.result).to eq(event_destroyed)
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
            {:shared, result: TestMessageController.destroy(event_destroyed)}
          end
          it do: expect(shared.result).to eq(event_destroyed)
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
            end
            it do 
              expect(fn -> TestMessageController.destroy(event) end) |> to(raise_exception RuntimeError)
              fresh_cmi = Repo.get(ConsumerMessageIndex, cmi.id)
              expect(StoppedPartition |> Repo.all |> Enum.count ).to eq(1)
              expect(fresh_cmi.id_message).to eq(550)
              expect(TestMessageController).to accepted(:test_callback, :any, count: 0)
              expect(:ets.lookup(:botsunit_wok_consumers_message_index, "bots_events_0"))
                    .to eq([{"bots_events_0", fresh_cmi}])
            end
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
              {:shared, changeset: changeset, exception: exception}
            end
            it do
              fresh_cmi = Repo.get(ConsumerMessageIndex, cmi.id)
              expect(StoppedPartition |> Repo.all |> Enum.count ).to eq(1)
              expect(fresh_cmi.id_message).to eq(550)
              expect(:ets.lookup(:botsunit_wok_consumers_message_index, "bots_events_0"))
                    .to eq([{"bots_events_0", fresh_cmi}])
              expect(String.match?(shared.exception.message, ~r/Wok Async Message Handler Exception @destroy$/))
            end
          end
        end
      end
    end
  end
end
