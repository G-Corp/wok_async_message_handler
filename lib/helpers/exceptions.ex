defmodule WokAsyncMessageHandler.Helpers.Exceptions do
  require Logger

  def throw_exception(exception, event, action, raise_after \\ true) do
    title = "#{Ecto.UUID.generate} Wok Async Message Handler Exception @#{action}"
    format_for_wok(exception, event, title)
    if raise_after, do: raise title
  end

  def format_for_wok(exception, event, title \\ "") do
    if Doteki.get_env([:wok_async_message_handler, :prod]) === true do
      %{
        title: title,
        event: "#{inspect(event)}",
        exception: "#{inspect exception}",
        message: "#{Exception.message(exception)}",
        stacktrace: format_stacktrace_as_json()
      }
      |> Poison.encode!
      |> Logger.error
    else
      "\n         #{title}\n"
      <> "         * event :\n"
      <> "           #{inspect event}\n"
      <> "         * exception :\n"
      <> "           #{inspect exception}\n"
      <> "         * message :\n"
      <> "           #{inspect Exception.message(exception)}\n"
      <> "         * stacktrace :\n"
      <> Enum.map_join(System.stacktrace, "\n", fn(stacktrace) ->
          case Enum.empty?(elem(stacktrace, 3)) do
            false ->  "           #{elem(stacktrace, 3)[:file]}:#{elem(stacktrace, 3)[:line]}"
            true ->   "           "
          end
          <> " #{elem(stacktrace, 0)}"
          <> ".#{elem(stacktrace, 1)}"
          <> case elem(stacktrace, 2) |> is_integer do
               true -> "/#{elem(stacktrace, 2)}"
               false -> " #{inspect elem(stacktrace, 2)}"
             end
         end)
      <> "\n\n"
      |> raise
    end
  end

  def format_stacktrace_as_json() do
    Enum.reduce(System.stacktrace, [], fn(stacktrace, list) ->
        error = case Enum.empty?(elem(stacktrace, 3)) do
          false ->  "#{elem(stacktrace, 3)[:file]}:#{elem(stacktrace, 3)[:line]}"
          true ->   ""
        end
        <> " #{elem(stacktrace, 0)}"
        <> ".#{elem(stacktrace, 1)}"
        <> case elem(stacktrace, 2) |> is_integer do
             true -> "/#{elem(stacktrace, 2)}"
             false -> " #{inspect elem(stacktrace, 2)}"
           end
        list ++ [error]
       end)
  end
end
