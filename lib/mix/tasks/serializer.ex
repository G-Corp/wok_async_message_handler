defmodule Mix.Tasks.WokAsyncMessageHandler.Serializer do
  use Mix.Task
  import Mix.Generator

  @shortdoc "Create serializer file for an ecto schema"

  def run(args) do
    schema = OptionParser.parse(args) |> elem(0) |> Keyword.get(:schema)
    app_name = Mix.Project.config[:app] |> to_string
    app_module = app_name |> Macro.camelize

    opts = [app_module: app_module, app_name: app_name, schema: schema]

    create_file Path.join(["lib", app_name, "message_serializers", schema |> Macro.underscore]) <> ".ex", serializer_template(opts)
  end

  embed_template :serializer, """
  defmodule <%= @app_module %>.MessageSerializers.<%= @schema %> do
    def message_versions, do: [1]

    def created(ecto_schema, version) do
      case version do
        1 -> %{id: ecto_schema.id}
      end
    end

    def updated(ecto_schema, version) do
      case version do
        1 -> %{id: ecto_schema.id}
      end
    end

    def destroyed(ecto_schema, version) do
      case version do
        1 -> %{id: ecto_schema.id}
      end
    end

    def partition_key(ecto_schema) do
      pkey = ecto_schema.id # use here the best data for your needs! ...
      unless Kernel.is_bitstring(pkey), do: raise("partition_key must be a string!") # ... it just must be a string
      pkey
    end

    def message_route(event), do: "<%= @app_name %>/<%= @schema |> Macro.underscore %>/\#{event}"
  end
  """
end
