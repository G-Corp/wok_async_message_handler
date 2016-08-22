defmodule WokAsyncMessageHandler.Helpers.Exceptions do
  require Logger

  def throw_exception(exception, event, action) do
    title = "#{Ecto.UUID.generate} Wok Async Message Handler Exception @#{action}"
    format_for_wok(exception, event, title)
    |> Logger.error
    throw title
  end

  def format_for_wok(exception, event, title \\ "") do
    "\n••••••••••••• #{title}\n"
    <> "  * event :\n"
    <> "    #{inspect event}\n"
    <> "  * exception :\n"
    <> "    #{inspect exception}\n"
    <> "  * message :\n"
    <> "    #{inspect Exception.message(exception)}\n"
    <> "  * stacktrace :\n"
    <> Enum.map_join(System.stacktrace, "\n", fn(stacktrace) ->
        case Enum.empty?(elem(stacktrace, 3)) do
          false ->  "    #{elem(stacktrace, 3)[:file]}:#{elem(stacktrace, 3)[:line]}"
          true ->   "    "
        end
        <> " #{elem(stacktrace, 0)}"
        <> ".#{elem(stacktrace, 1)}"
        <> case elem(stacktrace, 2) |> is_integer do
             true -> "/#{elem(stacktrace, 2)}"
             false -> " #{inspect elem(stacktrace, 2)}"
           end
       end)
    <> "\n\n"
  end
end
