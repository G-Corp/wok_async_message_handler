defmodule Mix.Tasks.WokAsyncMessageHandler.CleanTests do
  use Mix.Task

  @shortdoc "Clean generated files for tests"

  def run(_args) do
    File.rm_rf!("priv")
    File.rm_rf!("lib/wok_async_message_handler")
  end

end
