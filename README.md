# WokAsyncMessageHandler 0.0.1

* WokAsyncMessageHandler.MessagesEnqueuers.Ecto :  
module (macro to "use") to enqueue messages in database using Ecto, for asynchonous send to kafka by wok producer  
When you execute mix setup, a default enqueur is created for your project.  
A mix task allows to generate serializers for your ecto schema.  

* WokAsyncMessageHandler.MessagesHandlers.Ecto :  
module called asynchronously by wok producer.
It contains 2 functions  (```messages``` and ```response```) to give the next n messages to send and 
and process response after commit in kafka.  
(you don't need to do anything with this module. Just add the config as explain below and "it works")

* WokAsyncMessageHandler.MessageControllers.Base :  
module (macro to "use" in another module) to consume messages and 
store them in your database for events ```created```, ```updated```, ```destroyed```  
A mix task allows to generate controller for your ecto schema.  

## Installation

1. in your mix.exs file, include in deps :  
```
[...
  {:wok_async_message_handler, git: "git@gitlab.botsunit.com:msaas/wok_async_message_handler.git"},
...]
```

2. generate required files:  
```
mix wok_async_message_handler.init
```
This will create 3 ecto migrations, a serializers folder and a default message enqueur :
  - WokAsyncMessageHandler.Models.EctoProducerMessage :  
   store messages to send (3 fields : topic, partition, blob)
  - WokAsyncMessageHandler.Models.StoppedPartition :  
   store stopped partitions (when errors occur) and allow the connection to a monitoring system for example
  - WokAsyncMessageHandler.Models.ConsumerMessageIndex :  
   store the last message_id received from kafka for a {topic, partition} to prevent to process a message twice (if it has been committed twice in kafka)
  - lib/message_serializers :  
   directory to store message serializers for ecto schema("your models") (see below for generation)
  - lib/message_controllers :  
   directory to store message controllers for ecto schema("your models") (see below for generation)
  - lib/wok/gateway.ex :  
   a module to store messages to send in WokAsyncMessageHandler.Models.EctoProducerMessage  
   (YOU NEED TO PARAMETER THIS FILE! DON'T FORGET TO OPEN IT AND ADJUST SETTINGS!)

3. if required, create your database (mix ecto.create). Then, to create tables for wamh schema, run :
```
mix ecto.migrate
```

4. add to your config file :  
tell to WokAsyncMessageHandler.MessagesHandlers.Ecto which repo to use to fetch and delete messages  
```
config :wok_async_message_handler, messages_repo: MyApp.EctoRepo
```
tell to wok to use WokAsyncMessageHandler.MessagesHandlers.Ecto as messages handler  
```
config :wok, producer: [
              handler: WokAsyncMessageHandler.MessagesHandlers.Ecto, 
              frequency: 100, 
              number_of_messages: 1000
             ]
```

5. create a serializer for your each ecto schema you'll need to send as message (example : User Or Any resource mapped to db as a "model"):  
```
mix wok_async_message_handler.serializer --schema MyAppEctoSchema
```
Edit the generated serializer to add fields to serialization methods and customize "message_route" and "partition_key" functions to fit your needs. (see below for for detail of a serializer)  

6. send messages using the generated gateway (be sure to add them always in a SQL transaction):
```
{:ok, real_time_message} = MyApp.Wok.Gateway.enqueue_rtmessage(%{session_id: "my_session_id"})
...
{:ok, message} = 
MyApp.MyAppEctoSchema
|> MyApp.EctoRepo.get(1)
|> MyModule.FunctionToUpdateRecord
|> MyApp.Wok.Gateway.enqueue_message(:updated)
```

7. add the creation of WokAsyncMessageHandler.MessageControllers.Base.Helpers.ets_table to your app file :
```
:ets.new(WokAsyncMessageHandler.MessageControllers.Base.Helpers.ets_table, [:set, :public, :named_table])
```
(table to store the last message_id processed as a cache)

8. generate a messages controller for a model :
```
mix wok_async_message_handler.controller --schema MyEctoSchemaForAnEvent
```

9. edit the generated file to adjust parameters (see comments inside it)

10. map your wok handlers config to your controller and it will start consuming messages.  
By default, this consumer will consume :  
  - "created" : store a record in database, using message's payload.  
  - "destroyed" : delete a record from database, using message's payload.  
  - "updated" : update or create a record in database, using message's payload.  

that's it! You now can produce and consume messages.


## tests

To launch tests, you need to create a local file in config directory 
to setup database access (duplicate config/local.exs.example)
```
MIX_ENV=test mix wok_async_message_handler.init
mix espec
MIX_ENV=tests mix wok_async_message_handler.controller --schema MyAppEctoSchema #test controller generation
MIX_ENV=tests mix wok_async_message_handler.serializer --schema MyAppEctoSchema #test serializer generation
```
don't forget to clean your tests after (generated migrations files in priv/repo/migrations and  lib/wok_async_message_handler)  

## messages controllers

Messages controllers use an ets table as cache to keep the last processed message_id.  
You need to add this line to the start function of your application (or anywhere you want if you know what you do) :  
```
:ets.new(WokAsyncMessageHandler.MessageControllers.Base.Helpers.ets_table, [:set, :public, :named_table])
```

To generate a messages controller for a resource, use mix task :
```
mix wok_async_message_handler.controller --schema MyAppEctoSchema
```
Don't forget to use mix and ecto to generate a schema and a migration file for this resource.  
Go to created file and edit it as you need.  
After that, you need to map your wok handlers config to your controller and it will start consuming messages.  
By default, this consumer will consume : "created", "destroyed" and "updated" events.  
If you want you can add method in your controller to handle cutom events.  


You can use hooks in your controller. Just redefine these methods in your controller:  

* ```def on_update_before_update(attributes), do: attributes```
* ```def on_update_after_update(ecto_schema), do: {:ok, ecto_schema}```
* ```def on_destroy_before_delete(attributes), do: attributes```
* ```def on_destroy_after_delete(ecto_schema), do: {:ok, ecto_schema}```

**before** are called before the database update/delete and take the payload from the event as map.  
It returns a map used as the schema data for sql query.  
(The default hook as you can see returns just what's inside the payload = it does nothing)  
**after** are called just after the database update/delete and take the ecto schema returned by the query call as argument.  
It returns {:ok, ecto_schema}. If something else is returned, the transaction is canceled and the consumer will stop consuming 
this partition. It will be recorded in ```stopped_partitions``` table.

"create" code in WokAsyncMessageHandler.MessageControllers.Base is just an alias of "update" for now:  
```def create(event), do: update(event)```

By default, create/1, update/1, destroy/1 will do exactly what they need to to.
create will add a new record in the DB, mapping message fields to db table fields.
update will do the same (or insert if hte record doesn't exists)
destroy, will use the id in the message to delete the corresponding record in DB.
But you can rewrite create/1, update/1, destroy/1 if you need to have specific code for your application.  
Theses methods just take the row "event" and must return ```Wok.Message.no_reply()```  
```def create(event), do: ...[your code]... Wok.Message.no_reply()```  
```def destroy(event), do: ...[your code]... Wok.Message.no_reply()```  
```def update(event), do: ...[your code]... Wok.Message.no_reply()```  

If you set @master_key to a tuple {:master_id, "message_id"}, this will be used by update and delete to find record.
If my payload is ```{...message_id: 123...}```, then the generated SQL will be:
```
... WHERE master_id = 123 ...
```

## serializers

A serializer has multiple functions :
- **message_versions/0** : returns the list of supported messages serialization versions.  
You should not have more than 2 (or exceptionnaly 3) supported versions.  
When you want to generate a message, the handler will serialize all versions, using the serialization method for the event.  

- **created|updated|destroyed|[your event]/2** :  
serialization methods for events.
It takes two params (your ecto schema with data, and a version).  
You just need to define the map to return for json serialization.  

- **partition_key/1** :
THIS MUST RETURN A STRING.  
Returns the partition key for kafka. Often your ID or MASTER_ID.  
If you return an integer, it will be send to this partition number, but this behavior is not wanted here.  

- **message_route/1** :
the 'to' field in your message.  

## "Produce" part

### WokAsyncMessageHandler.MessagesEnqueuers.Ecto.enqueue_rtmessage/2

Use this method when you want to send a real time message.  
It will build and store the message to send in your database with these default fields:
* topic: @realtime_topic value from handler
* partition_key: the value of the field specified by ```:pkey``` attribute of the second function's arg (options map)
* from: producer_name value of handler
* to: "#{handler's producer_name}/real_time/notify"  

The message will be then send later by the producer.  

You can redefine defaul fields if you need:
```
WokAsyncMessageHandler.MessagesEnqueuers.Ecto.enqueue_rtmessage(
  %{data1: value1, data2: value2...}, # a map where you specify your payload's data
  %{pkey: :data2, from: "my_from", to: "my_custom_to"} #optionnal and each key is optionnal too
)
```

THIS METHOD DOESN'T HANDLE VERSIONING OF RT MESSAGES FOR NOW.  

Example: If you need to send messages to a session_id, call :
```
WokAsyncMessageHandler.MessagesEnqueuers.Ecto.enqueue_rtmessage(%{session_id: my_session_id})
```
The whole map will be merged into message :payload value.  
If you don't specify a "source" field, it will be added to your payload with @producer_name as value.  
IE, ```enqueue_rtmessage(%{session_id: my_session_id})``` will have a payload field with ```%{session_id: my_session_id, source: @producer_name}```  

This method accepts options list as second arg. You can define these fields:
* ```:pkey``` : atom, let you specify which key from the first map you want to use get the value for partition key.  
* ```:from``` : string, let you specify a custom ```from``` for the message.  
* ```:to``` : string, let you specify a custom ```to``` for the message.  
* ```:metadata```: any value, added as metadata in message body.

By default, and you should not use it, if you don't specify ```:pkey```, the map is cast to a keyword list and the first value is used as partition key (Map.to_list reorder the keys in alphabetical order).  

### WokAsyncMessageHandler.MessagesEnqueuers.Ecto.enqueue_message/3

```
WokAsyncMessageHandler.MessagesEnqueuers.Ecto.enqueue_message(
  ecto_schema,  # your data / model / ecto_schema
  event, # the event you want to produce. Usually :created | :updated | :destroyed
  [metadata: :any_value, topic: "optionnal_topic"] # optionnal
```
Use this method when you want to send a message/event in your broker.  
It will build and store the message in your database with the parameters defined in the handler.  
This method accepts options list as second arg. You can define these fields:
* ```:topic``` : string, topic where you want to send the message, default to generated gateway's attribute @messages_topic
* ```:metadata```: any value, added as metadata in message body.















# WokAsyncMessageHandler : 0.0.0 (deprecated) 

## Message production

Async message producer to use with wok >= 0.4.4  
Handle producer part and consumer part.  
Include mix task to generate ecto migrations for messages and partitions.  
Include mix task to generate serializer for ecto schema (your "model").  
Include mix task to generate messages controllers for ecto schema. (consumer aprt of the lib)   

The **WokAsyncMessageHandler.Bases.Ecto** module when used (with the 'use' macro)
in another module allows to register messages in a table (autogenerated) of your PG database.  
This table is used as a queue for wok to send your messages asynchronously to your message broker (kafka).
Using it in a SQL transaction in your code garanties your messages reflect exactly
your DB state when they are written to BD and that they will be sent to your message broker later,
 no matter what happens, by wok producer process.  
When a message is registered, its id (autoincremented column by PG, send in wok message headers as "message_id" param)
lets your consumers, when they receive the message, know if they already have processed this message.  
It's an "at least once message dispatch, at least once message delivered and exactly once message processed" flow.  

The **WokAsyncMessageHandler.MessageControllers.Base** module allows to define messages controllers in your application to consume messages.  
Thanks to message_id header, it prevents to process multiple times the same message.  
It natively consumes ```created``` (add a new record in db), ```updated``` (insert or update a record in db) and ```destroyed``` (delete a record from db) event.  
Look below for more information about it.  

## Installation

in your mix.exs file, include in deps :
```
[...
  {:wok_async_message_handler, git: "git@gitlab.botsunit.com:msaas/wok_async_message_handler.git", branch: "master"},
...]
```

generate required files:
```
mix wok_async_message_handler.init
```
This will create 2 ecto migrations, a serializers folder and a default message handler:
- WokAsyncMessageHandler.Models.EctoProducerMessage to store messages to send (3 fields : topic, partition, blob)
- WokAsyncMessageHandler.Models.StoppedPartition to store stopped partition (when errors occur) and allow the connection to a monitoring system for example
- lib/message_serializers directory to store message serializers for ecto schema (see below for generation)
- lib/message_controllers directory to store message controllers for ecto schema (see below for generation)
- lib/services/wok_async_message_handler.ex where a default message handler is generated for you (YOU NEED TO PARAMETER THIS!!!!! DON'T FORGET!!!)

if need, create your database (mix ecto.create), then run :
```
mix ecto.migrate
```

add to your config file :
```
config :wok, producer: [handler: WokAsyncMessageHandler.MessagesHandlers.Ecto, frequency: 100, number_of_messages: 1000]
```

create a serializer for your ecto schema MyAppEctoSchema (example : User Or Any resource mapped to db as a "model"):
```
mix wok_async_message_handler.serializer --schema MyAppEctoSchema
```
Edit the generated serializer to add fields to serialization methods and customize "message_route" and "partition_key" functions to fit your needs. (see below for for detail of a serializer)  

and now you can call functions in your code (be sure to add them always in a SQL transaction):
```
{:ok, message} = WokAsyncMessageHandler.Helpers.RealTimeMessages.build_and_store(MyApp.Services.WokAsyncMessageHandler, %{session_id: "my_session_id"})
...
my_app_ecto_schema = MyApp.Datastores.PG.get(MyApp.MyAppEctoSchema, 1)
{:ok, message} = WokAsyncMessageHandler.Helpers.Messages.build_and_store(MyApp.Services.WokAsyncMessageHandler, my_app_ecto_schema, :created, "my_topic")
```



## helpers (deprecated)

### WokAsyncMessageHandler.Helpers.RealTimeMessages

* build_and_store/3  
Use this method when you want to send realtime messages.  
It will build and store the message to send in your database with these default fields:
* topic: @realtime_topic value from handler
* partition_key: THE FIRST VALUE of the data map (see below for more info)
* from: producer_name value of handler
* to: "#{handler.producer_name}/real_time/notify"  

The message will be then send later by the producer.  

You can redefine defaul fields if you need:
```
WokAsyncMessageHandler.Helpers.RealTimeMessages.build_and_store(
  MyApp.Services.WokAsyncMessageHandler,  # message handler to use to build and store message
  %{data1: value1, data2: value2...}, # a map where you specify your payload's data
  %{pkey: :data2, from: "my_from", to: "my_custom_to"} #optionnal and each key is optionnal too
)
```

THIS METHOD DOESN'T HANDLE VERSIONING OF RT MESSAGES FOR NOW.  

Example: If you need to send messages to a session_id, call :
```
WokAsyncMessageHandler.Helpers.RealTimeMessages.build_and_store(%{session_id: my_session_id})
```
The whole map will be merged into message :payload value. If you don't specify a "source" field, it will be added to your payload with @producer_name as value.  
IE, ```build_and_store(%{session_id: my_session_id})``` will have a payload field with ```%{session_id: my_session_id, source: @producer_name}```  

This method accepts an options (map) as second param. You can add these fields in this map:
* ```:pkey``` : atom, let you specify which key from the first map you want to use get the value for partition key.  
* ```:from``` : string, let you specify a custom ```from``` for the message.  
* ```:to``` : string, let you specify a custom ```to``` for the message.  

By default, and you should not use it, if you don't specify ```:pkey```, the first value of the map will be used as partition key.  

### WokAsyncMessageHandler.Helpers.Messages

* build_and_store/4  

```
WokAsyncMessageHandler.Helpers.Messages.build_and_store(
  MyApp.Services.WokAsyncMessageHandler,  # message handler to use to build and store message
  ecto_schema,  # your data / model / ecto_schema
  event, # the event you want to produce. Usually :created | :updated | :destroyed
  topic, # topic where you want to send the message
```
Use this method when you want to send a message/event in your broker.  
It will build and store the message  in your database with the parameters defined in the handler.  
