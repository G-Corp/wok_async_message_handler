# WokAsyncMessageHandler

Async message producer to use with wok 0.4.4
Include mix task to generate ecto migrations for messages and partitions managed

## Installation

in your mix.exs file, include in deps:
```
[...
  {:wok_async_message_handler, git: "git@gitlab.botsunit.com:msaas/wok_async_message_handler.git"},
...]
```

generate migrations (only for Ecto):
```
mix async_wok_message_handler.init
```

if need, create your database (mix ecto.create), then run :
```
mix ecto.migrate
```

in your code, create a file to implement your message handler:
```
defmodule MyApp.Services.EctoMessageProducer do
  @application :my_app
  @producer_name "name_used_for__from__field_in_messages"
  @realtime_topic "name_of_realtime_topic_where_rt_messages_will_be_produced"
  @datastore MyApp.Datastores.PG #Ecto repo where we will store messages before they are sent (message queue)
  @serializers MyApp.MessageSerializers #module hierarchy where you will create your serializers for messages
  use WokAsyncMessageHandler.Bases.Ecto
end
```

create a serializer for your ecto schema MyAppEctoSchema:
```
defmodule MyApp.MessageSerializers.MyAppEctoSchema do
  def message_versions, do: [1] #list of supported messages versions
  def created(ecto_schema, _version), do: %{id: ecto_schema.id, field1: value1, ...} #serialization for 'created' event
  def updated(ecto_schema, _version), do: %{id: ecto_schema.id, field1: value1, ...} #serialization for 'updated' event
  def destroyed(ecto_schema, _version), do: %{id: ecto_schema.id} #serialization for 'destroyed' event (often just id)
  def partition_key(ecto_schema), do: ecto_schema.id # schema field used to determine partition id
  def message_route(event), do: "bot/resource/#{event}" # message route for "to" field in messages
end
```

and now you can call functions in your code:
```
{:ok, message} = MyApp.Services.EctoMessageProducer
                 .create_and_add_rt_notification_to_message_queue(%{session_id: "my_session_id"})
...
my_app_ecto_schema = MyApp.Datastores.PG.get(MyApp.MyAppEctoSchema, 1)
{:ok, message} = MessageProducer.create_and_add_message_to_message_queue(my_app_ecto_schema, :created, "my_topic")
```
