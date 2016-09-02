defmodule WokAsyncMessageHandler.Helpers.TestMessage do
  @bot_name "user"

  require Record


  Record.defrecord(:message_transfert, 
   Record.extract(
     :message_transfert, 
     from_lib: "wok_message_handler/include/wok_message_handler.hrl"
   )
 ) 

 Record.defrecord(:wok_msg,
  Record.extract(
    :wok_msg, 
    from_lib: "wok_message_handler/include/wok_message_handler.hrl"
  )
)

Record.defrecord(:message,
 Record.extract(
   :message, 
   from_lib: "wok_message_handler/include/wok_message_handler.hrl"
 )
 )

 def build_event_message(payload, to) do
   message_transfert(
     message: build_message(payload, to),
     partition: 1,
     topic: "bots_events"
   )
 end

 defp build_message(payload, to) do
   wok_msg(
     message: message(
       uuid: Ecto.UUID.generate,
       to: to,
       from: @bot_name,
       params: %{},
       headers: %{message_id: 1},
       body: build_message_body(payload)
     )
   )
 end

 defp build_message_body(payload, version \\ 1) do
   [%{
     version: version,
     payload: payload
   }] |> Poison.encode!
 end

end
