defmodule WokAsyncMessageHandler.MessageControllers.Base do
  defmacro __using__(_options) do

    quote do
      import WokAsyncMessageHandler.MessageControllers.Base.Helpers
      alias WokAsyncMessageHandler.Helpers.Exceptions

      def message_version, do: @message_version
      def datastore, do: @datastore
      def model, do: @model
      def keys_mapping, do: @keys_mapping
      def master_key, do: @master_key

      def create(event), do: update(event)

      def destroy(event) do
        try do
          do_destroy(__MODULE__, event)
        rescue
          e -> Exceptions.throw_exception(e, event, :destroy)
        end
      end

      def update(event) do
        try do
          do_update(__MODULE__, event)
        rescue
          e -> Exceptions.throw_exception(e, event, :update)
        end
      end

      def on_create_before_insert(attributes), do: attributes
      def on_create_after_insert(ecto_schema), do: {:ok, ecto_schema}
      def on_update_before_update(attributes), do: attributes
      def on_update_after_update(ecto_schema), do: {:ok, ecto_schema}
      def on_destroy_before_delete(attributes), do: attributes
      def on_destroy_after_delete(ecto_schema), do: {:ok, ecto_schema}

      defoverridable [
        on_create_after_insert: 1,
        on_create_before_insert: 1,
        on_destroy_before_delete: 1,
        on_destroy_after_delete: 1,
        on_update_after_update: 1,
        on_update_before_update: 1,
        create: 1,
        destroy: 1,
        update: 1
      ]
    end
  end

  defmodule Helpers do
    import Ecto.Query
    require Logger
    require Record
    Record.defrecord :message_transfert, Record.extract(:message_transfert, from_lib: "wok_message_handler/include/wok_message_handler.hrl")
    alias WokAsyncMessageHandler.Models.ConsumerMessageIndex
    @indexes_ets_table :botsunit_wok_consumers_message_index

    def ets_table, do: @indexes_ets_table

    def do_update(controller, event) do
      if message_not_already_processed?(controller, event) do
        {:ok, consumer_message_index} = controller.datastore.transaction(fn() ->
          {record, _payload} = record_and_payload_from_event(controller, event)
          attributes = attributes_from_event(event, controller.message_version, controller.keys_mapping)
                       |> controller.on_update_before_update()

          controller.model.update_changeset(record, attributes)
          |> controller.datastore.insert_or_update()
          |> case do
            {:ok, ecto_schema} ->
              {:ok, _} = controller.on_update_after_update(ecto_schema)
              update_consumer_message_index(controller, event)
            {:error, ecto_changeset} ->
              Logger.warn "Unable to update #{inspect controller.model} with attributes #{inspect attributes}"
              controller.datastore.rollback(ecto_changeset)
          end
        end)
        update_consumer_message_index_ets(consumer_message_index)
      end
      Wok.Message.noreply(event)
    end

    def do_destroy(controller, event) do
      if message_not_already_processed?(controller, event) do
        {:ok, consumer_message_index} = controller.datastore.transaction(fn() ->
          attributes = attributes_from_event(event, controller.message_version, controller.keys_mapping)
                       |> controller.on_destroy_before_delete()
          case controller.datastore.get(controller.model, attributes.id) do
            nil ->
              Logger.warn "No match for destroyed #{inspect controller.model} with id #{attributes.id}"
              update_consumer_message_index(controller, event)
            ecto_schema ->
              Logger.info "Destroying #{inspect controller.model} with id #{attributes.id}"
              case controller.datastore.delete(ecto_schema) do
                {:ok, ecto_schema} ->
                  {:ok, _} = controller.on_destroy_after_delete(ecto_schema)
                  update_consumer_message_index(controller, event)
                {:error, ecto_changeset} ->
                  Logger.info "Unable to destroy #{inspect controller.model} with id #{attributes.id}"
                  controller.datastore.rollback(ecto_changeset)
              end
          end
        end)
        update_consumer_message_index_ets(consumer_message_index)
      end
      Wok.Message.noreply(event)
    end

    defp message_not_already_processed?(controller, event) do
      Wok.Message.headers(event).message_id > find_last_processed_message_id(controller, event)
    end

    defp update_consumer_message_index_ets(consumer_message_index) do
      true = :ets.insert(@indexes_ets_table, {build_ets_key(consumer_message_index), consumer_message_index})
    end

    defp get_consumer_message_index_ets(ets_key) do
      [{^ets_key, schema}] = :ets.lookup(@indexes_ets_table, ets_key)
      schema
    end

    defp update_consumer_message_index(controller, event) do
      topic = message_transfert(event, :topic)
      partition = message_transfert(event, :partition)
      message_id = Wok.Message.headers(event).message_id
      ets_key = build_ets_key(topic, partition)
      schema = get_consumer_message_index_ets(ets_key)
      case ConsumerMessageIndex.changeset(schema, %{id_message: message_id})
           |> controller.datastore.update() do
        {:ok, updated_schema} -> updated_schema
        {:error, ecto_changeset} ->
          Logger.info "Unable to update message index #{inspect ecto_changeset} with id #{schema.id}"
          controller.datastore.rollback(ecto_changeset)
      end
    end

    defp build_ets_key(topic, partition), do: "#{topic}_#{partition}"
    defp build_ets_key(consumer_message_index) do
      "#{consumer_message_index.topic}_#{consumer_message_index.partition}"
    end

    defp find_last_processed_message_id(controller, event) do
      topic = message_transfert(event, :topic)
      partition = message_transfert(event, :partition)
      ets_key = build_ets_key(topic, partition)
      last_processed_message_id =
        case :ets.lookup(@indexes_ets_table, ets_key) do
          [] ->
            case from(c in ConsumerMessageIndex, where: [topic: ^topic, partition: ^partition])
                 |> controller.datastore.one do
              nil ->
                ecto_schema = controller.datastore.insert!(%ConsumerMessageIndex{topic: topic, partition: partition, id_message: -1})
                update_consumer_message_index_ets(ecto_schema)
                ecto_schema.id_message
              ecto_schema ->
                update_consumer_message_index_ets(ecto_schema)
                ecto_schema.id_message
            end
          [{^ets_key, ecto_schema}] ->
            ecto_schema.id_message
        end
      last_processed_message_id
    end

    defp attributes_from_event(event, version, atom_changeset) do
      event
      |> expected_version_of_payload(version)
      |> map_payload_to_attributes(atom_changeset)
    end

    defp record_and_payload_from_event(controller, event) do
      payload = expected_version_of_payload(event, controller.message_version)
      if controller.master_key != nil do
        controller.datastore.get_by(
          controller.model,
          [{elem(controller.master_key, 0), payload[elem(controller.master_key, 1)]}]
        )
      else
        controller.datastore.get(controller.model, payload["id"])
      end
      |> case do
        nil -> {struct(controller.model), payload}
        record -> {record, payload}
      end
    end

    defp expected_version_of_payload(message, version) do
      Wok.Message.body(message)
      |> log_message(Wok.Message.to(message))
      |> Poison.decode!
      |> Enum.find(&(&1["version"] == version))
      |> Map.get("payload", :no_payload)
    end

    defp log_message(body, to) do
      Logger.info "Message received: #{to} #{body}"
      body
    end

    defp map_payload_to_attributes(payload, atom_changeset) do
      for {key, val} <- payload, into: %{} do
        {Map.get(atom_changeset, key, String.to_atom(key)), val}
      end
    end
  end
end
