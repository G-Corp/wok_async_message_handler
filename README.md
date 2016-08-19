# WokAsyncMessageHandler

Async message producer to use with wok 0.4.4
Include mix task to generate ecto migrations for messages and partitions.
Include mix task to generate serializer for ecto schema.
The WokAsyncMessageHandler.Bases.Ecto module when used (with the 'use' macro)
in another module allows to register messages to send in a queue in your PG database.
Using it in a SQL transaction in your code garanties your messages reflect exactly
your DB state when they are written to BD and that they will be sent to your message broker later,
 no matter what happens, by wok producer process.
When a message is registered, its id (autoincremented column by PG, send in wok message headers as "message_id" param)
lets your consumers know if they already have processed this message.
It's an "at least once message dispatch, at least once message delivered and exactly once message processed" flow.


## Installation

in your mix.exs file, include in deps:
```
[...
  {:wok_async_message_handler, git: "git@gitlab.botsunit.com:msaas/wok_async_message_handler.git"},
...]
```

generate required files:
```
mix wok_async_message_handler.init
```
This will create 2 ecto migrations and their schema module, serializers folder and a default message handler:
- WokAsyncMessageHandler.Models.EctoProducerMessage to store messages to send (3 fields : topic, partition, blob)
- WokAsyncMessageHandler.Models.StoppedPartition to store stopped partition (when errors occur) and allow the connection to a monitoring system for example
- lib/message_serializers directory to store message serializers for ecto schema
- lib/services/wok_async_message_handler.ex where a default message handler is generated for you

if need, create your database (mix ecto.create), then run :
```
mix ecto.migrate
```

add to your config file:
```
config :wok, producer: [handler: MyApp.Services.EctoMessageProducer, frequency: 100, number_of_messages: 1000]
```

create a serializer for your ecto schema MyAppEctoSchema:
```
mix wok_async_message_handler.serializer --schema MyAppEctoSchema
```
Edit the generated serializer to add fields to serialization methods

and now you can call functions in your code (be sure to add them always in a SQL transaction):
```
{:ok, message} = MyApp.Services.EctoMessageProducer
                 .create_and_add_rt_notification_to_message_queue(%{session_id: "my_session_id"})
...
my_app_ecto_schema = MyApp.Datastores.PG.get(MyApp.MyAppEctoSchema, 1)
{:ok, message} = MessageProducer.create_and_add_message_to_message_queue(my_app_ecto_schema, :created, "my_topic")
```

## test

create a local file in config directory to configure database access (duplicate config/local.exs.example if ok)
```
MIX_ENV=test mix ecto.drop
MIX_ENV=test mix wok_async_message_handler.init
MIX_ENV=test mix ecto.create
MIX_ENV=test mix ecto.migrate
mix espec
```
don't forget to clean your tests after (generated migrations files in priv/repo/migrations)
