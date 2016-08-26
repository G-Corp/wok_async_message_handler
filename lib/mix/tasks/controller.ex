defmodule Mix.Tasks.WokAsyncMessageHandler.Controller do
  use Mix.Task
  import Mix.Generator

  @shortdoc "Create controller file for an ecto schema"

  def run(args) do
    schema = OptionParser.parse(args) |> elem(0) |> Keyword.get(:schema)
    app_name = Mix.Project.config[:app] |> to_string
    app_module = app_name |> Macro.camelize
    host_app_main_repo = Mix.Ecto.parse_repo([]) |> IO.inspect |> List.first

    opts = [app_module: app_module, repo: host_app_main_repo, schema: schema]

    create_file Path.join(["lib", app_name, "message_controllers", schema |> Macro.underscore]) <> "_controller.ex", controller_template(opts)

    msg = "\ncontroller created. Open the file to check if everything is ok. Modify it to fit your needs.
\nDon't forget to create a migration and a schema for your resource with mix and ecto.\n\n"
    Mix.shell.info [msg]
  end

  embed_template :controller, """
  defmodule <%= @app_module %>.MessagesController.<%= @schema %>Controller do
    @message_version 1 # handled message version
    @datastore <%= @repo %> # repo for your resource
    @model <%= @schema %> # Resource you will receive messages for
    @keys_mapping %{} # Map to remap fields name between messages and your db schema : %{"a" -> :b} will remap "a" found in your message to attribute :b. It's always "string" to "atom".
    use WokAsyncMessageHandler.MessageControllers.Base
  end
  """
end
