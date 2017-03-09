# WokAsyncMessageHandler 0.0.1

**if you update from an older version, just run ```mix wok_async_message_handler.init```.**  
**This will generate new files without touching the old ones.**  
**You can then run commands ```ecto.migrate``` etc etc to update**  



* WokAsyncMessageHandler.MessagesEnqueuers.Ecto :  
module (macro to "use") to enqueue messages in database using Ecto, for asynchonous send to kafka by wok producer  
When you execute mix setup, a default enqueuer "YourApp.Wok.Gateway" is created for your project.  
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
This will create 3 ecto migrations, a serializers folder and a default message enqueuer :
  - WokAsyncMessageHandler.Models.EctoProducerMessage :  
   store messages to send (3 fields : topic, partition, blob)
  - WokAsyncMessageHandler.Models.StoppedPartition :  
   store stopped partitions (when errors occur) and allow the connection to a monitoring system for example
  - WokAsyncMessageHandler.Models.ConsumerMessageIndex :  
   store the last message_id received from kafka for a bot to prevent processing a message twice (if it has been committed twice in kafka)
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

5. create a serializer for each ecto schema you'll need to send as message (example : User Or Any resource mapped to db as a "model"):  
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
(ets table to store the last message_id processed as a cache)  
**this table needs to be created when your application starts, or before the first call to this table is done.**  
For an elixir project named MyApp, you can put it into the generated file lib/my_app.ex, into ```start``` method  

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

11. **for production only**, to format exceptions as json in error.log, add this line to your config file:  
```
config :wok_async_message_handler, prod: true
```

12. **for test only**, between each test, be sure to init your ets table for consumer message index :  
```
if( :ets.info(WokAsyncMessageHandler.MessageControllers.Base.Helpers.ets_table) != :undefined ) do
  :ets.delete_all_objects(WokAsyncMessageHandler.MessageControllers.Base.Helpers.ets_table)
end
```

13. **for test only**, Use helpers for your tests to generate fake messages for your messages controllers:  
```
WokAsyncMessageHandler.Helpers.TestMessage.build_event_message(%{id: 123, ...}, "from_bot", 1, 1, "topic")  
```
arguments are:  
  - payload : map, your data  
  - from : string, sender of the event  
  - message_id : integer, message id set into headers  
  - partition : integer, broker partition id  
  - topic : string, topic  

14. **for test only**, use helpers to validate a stored message in database is what you expected:
```
WokAsyncMessageHandler.Helpers.TestMessage.payload_to_wok_message("topic", "partition_key", "from", "to", %{version: 1, payload: %{k: "v"}, metadata: %{...}})
```


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
don't forget to clean your tests after (generated migrations files in priv/repo/migrations and  lib/wok_async_message_handler):  
```
MIX_ENV=test mix wok_async_message_handler.clean_tests
```

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


You can use hooks in your controller.
All hooks takes a map ("event_data") as arguments, and must return an enriched version of the same map.
They work as chained callbacks: each callback receive the "event_data" the precedent callback returns.
With this mechanism you can add data to pass to other callbacks (like "metadata" from body).
**Do not remove initial data, or your app can raise an exception. You can change data inside maps, but do not delete any data
if you are not sure of what you do.**

To use hooks in your code, just override these methods in your controller:  

* ```def process_create(controller, event)```
  * this method by default register the model into your database.
  * It can return:
  * {:ok, data} : data will be argument for after_create callback. By default it is the struct returned by ecto insert
  * {:error, data} : will rollback the transaction and stop the bot. By default it is the changeset returned by ecto insert
* ```def before_create(event_data)```
  * it returns an enriched "event_data" map
  * if you use the default process_create function, you can redefine this function
  * this callback is by default called INSIDE ```process_create```
  * if you rewrite your own ```process_create```, this callback is no more called, except if you put it in your code again.
* ```def after_create(data)```
  * this callback is called OUTSIDE process_create (= always!) and take a data (by default the struct returned by ecto insert).
  * it returns a tuple ```{:ok, ...}```. For now, only :ok is checked for success.
  * if you rewrite your own ```process_create```, this callback is still called.

Others callbacks work the same way:

* ```def process_update(event_data_returned_from_before_update)```
* ```def before_update(%{body: versioned_body, payload: payload_from_body, record: found_or_empty_struct} = event_data)```
* ```def after_update(%{body: versioned_body, payload: payload_from_body, record: inserted_or_updated_struct[,your_data: %{...}]} = event_data)```
* ```def before_destroy(%{body: versioned_body, payload: payload_from_body, record: found_struct_or_nil} = event_data)```
* ```def process_destroy(event_data_returned_from_before_destroy)```
* ```def after_destroy(%{body: versioned_body, payload: payload_from_body, record: nil_or_deleted_struct[,your_data: %{...}]} = event_data)```

**before** are called before the database update/delete.  
It returns an enriched "event_data" map.  
(The default hook as you can see returns just what's inside the event_data = it does nothing)  
**after** are called just after the database update/delete.  
It returns {:ok, event_data}. If something else is returned, the transaction is canceled and 
the consumer will stop consuming this partition. This failure will be recorded in ```stopped_partitions``` table.

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

You can use public methods from WokAsyncMessageHandler.MessageControllers.Base.Helpers to manipulate messages data:  
* expected_version_of_body
* record_and_body_from_event
* build_ets_key
* update_consumer_message_index
* message_not_already_processed?
* update_consumer_message_index_ets
* event_data_with_attributes



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

## Licence

wok_async_message_handler is available for use under the following license, commonly known as the 3-clause (or "modified") BSD license:

Copyright (c) 2016, 2017 BotsUnit<br />

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
* The name of the author may not be used to endorse or promote products derived from this software without specific prior written permission.



THIS SOFTWARE IS PROVIDED BY THE AUTHOR `AS IS` AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

