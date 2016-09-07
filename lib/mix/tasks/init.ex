defmodule Mix.Tasks.WokAsyncMessageHandler.Init do
  use Mix.Task
  import Mix.Generator

  @shortdoc "Create migration files for Ecto"

  def run(_args) do
    app_name = Mix.Project.config[:app] |> to_string
    app_module = app_name |> Macro.camelize
    host_app_main_repo = Mix.Ecto.parse_repo([]) |> List.first

    migrations_path = Path.join("priv/#{host_app_main_repo |> Module.split |> List.last |> Macro.underscore}", "migrations")

    create_directory(migrations_path)
    unless file_exists?(migrations_path, "*_add_ecto_producer_message.exs") do
      file = Path.join(migrations_path, "#{timestamp()}_add_ecto_producer_message.exs")
      create_file file, migration_template([host_app_main_repo: host_app_main_repo])
      :timer.sleep(1000)
    end
    unless file_exists?(migrations_path, "*_add_ecto_producer_stopped_partitions.exs") do
      file = Path.join(migrations_path, "#{timestamp()}_add_ecto_producer_stopped_partitions.exs")
      create_file file, stopped_partitions_template([host_app_main_repo: host_app_main_repo])
      :timer.sleep(1000)
    end
    unless file_exists?(migrations_path, "*_add_consumer_messages_indexes.exs") do
      file = Path.join(migrations_path, "#{timestamp()}_add_consumer_messages_indexes.exs")
      create_file file, partition_indexes_template([host_app_main_repo: host_app_main_repo])
      :timer.sleep(1000)
    end

    generate_migration_for_cmi_with_from_index(migrations_path, host_app_main_repo)
    generate_migration_for_cmi_add_partition_and_topic(migrations_path, host_app_main_repo)

    default_service = Path.join(["lib", app_name, "wok"])
    create_directory(default_service)

    unless file_exists?(default_service, "*gateway.ex") do
      default_service
      |> Path.join("gateway.ex")
      |> create_file(service_template([app_module: app_module, app_name: app_name, repo: host_app_main_repo]))
    end
    create_directory(Path.join ["lib", app_name, "message_serializers"] )
    create_directory(Path.join ["lib", app_name, "message_controllers"] )

    msg = "
WokAsyncMessageHandler initialized.

All files generated. To finish setup, add this line to your config file:
    config :wok, producer: [handler: #{app_module}.Wok.Gateway, frequency: 100, number_of_messages: 1000]
    config :wok_async_message_handler, messages_repo: #{inspect host_app_main_repo}

lib/#{app_name}/wok/gateway.ex is a default message gateway generated for you (YOU NEED TO PARAMETER THIS!!!!! DON'T FORGET TO LOOK AT IT!)
generate serializers for your ecto schema:
    mix wok_async_message_handler.serializer --schema MyAppEctoSchema
and produce messages!

generate messages controller to consume events from kafka:
    mix wok_async_message_handler.controller --schema MyEctoSchemaForAnEvent

"
    Mix.shell.info [msg]
  end

  defp generate_migration_for_cmi_with_from_index(migrations_path, host_app_main_repo) do
    unless file_exists?(migrations_path, "*_cmi_with_from.exs") do
      file = Path.join(migrations_path, "#{timestamp()}_cmi_with_from.exs")
      create_file file, cmi_from_update_template([host_app_main_repo: host_app_main_repo])
      :timer.sleep(1000)
    end
  end

  defp generate_migration_for_cmi_add_partition_and_topic(migrations_path, host_app_main_repo) do
    unless file_exists?(migrations_path, "*_cmi_add_partition_and_topic.exs") do
      file = Path.join(migrations_path, "#{timestamp()}_cmi_add_partition_and_topic.exs")
      create_file file, cmi_add_partition_and_topic_template([host_app_main_repo: host_app_main_repo])
      :timer.sleep(1000)
    end
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: << ?0, ?0 + i >>
  defp pad(i), do: to_string(i)

  embed_template :migration, """
  defmodule <%= inspect @host_app_main_repo %>.Migrations.AddEctoProducerMessage do
    use Ecto.Migration

    def change do
      create table(:ecto_producer_messages) do
        add :topic, :string, null: false
        add :partition, :integer, null: false
        add :blob, :text, null: false
        timestamps
      end
      create index(:ecto_producer_messages, [:topic])
      create index(:ecto_producer_messages, [:partition])
    end
  end
  """

  embed_template :stopped_partitions, """
  defmodule <%= inspect @host_app_main_repo %>.Migrations.AddWokProducerStoppedPartitions do
    use Ecto.Migration

    def change do
      create table(:stopped_partitions) do
        add :topic, :string, null: false
        add :partition, :integer, null: false
        add :message_id, :integer, null: false
        add :error, :text, null: false
        timestamps
      end
    end
  end

  """

  embed_template :service, """
  defmodule <%= @app_module %>.Wok.Gateway do
    @application :<%= @app_name %> #should be your app name
    @producer_name "<%= @app_name %>" #'from' field in messages
    @realtime_topic "" #don't leave this blank!
    @messages_topic "" #don't leave this blank!
    @datastore <%= inspect @repo %> #store module for messages
    @serializers <%= @app_module %>.MessageSerializers #your serializers module "namespace"
    use WokAsyncMessageHandler.MessagesEnqueuers.Ecto
  end

  """

  embed_template :partition_indexes, """
  defmodule <%= inspect @host_app_main_repo %>.Migrations.AddConsumerMessageIndexes do
    use Ecto.Migration

    def change do
      create table(:consumer_message_indexes) do
        add :topic, :string, null: false
        add :partition, :integer, null: false
        add :id_message, :integer, null: false
        timestamps
      end
      create index(:consumer_message_indexes, [:partition])
      create index(:consumer_message_indexes, [:topic])
    end
  end
  """

  embed_template :cmi_from_update, """
  defmodule <%= inspect @host_app_main_repo %>.Migrations.CmiFromUpdate do
    use Ecto.Migration

    def change do
      alter table(:consumer_message_indexes) do
        add :from, :string, null: false
        remove :topic
        remove :partition
      end
      create index(:consumer_message_indexes, [:from])
    end
  end
  """


  embed_template :cmi_add_partition_and_topic, """
  defmodule <%= inspect @host_app_main_repo %>.Migrations.CmiWithPartitionAndTopic do
    use Ecto.Migration

    def change do
      <%= inspect @host_app_main_repo %>.delete_all(WokAsyncMessageHandler.Models.ConsumerMessageIndex)
      alter table(:consumer_message_indexes) do
        add :partition, :integer, null: false
        add :topic, :string, null: false
      end
      create index(:consumer_message_indexes, [:partition])
      create index(:consumer_message_indexes, [:topic])
    end
  end
  """

  embed_template :use_big_int, """
  defmodule <%= inspect @host_app_main_repo %>.Migrations.CMIUseBigInt do
    use Ecto.Migration

    def change do
      <%= inspect @host_app_main_repo %>.delete_all(WokAsyncMessageHandler.Models.ConsumerMessageIndex)
      alter table(:consumer_message_indexes) do
        modify :id_message, :int8
      end
      create index(:consumer_message_indexes, [:partition])
      create index(:consumer_message_indexes, [:topic])
    end
  end
  """

  defp file_exists?(migrations_path, globe) do
    [] != migrations_path |> Path.join(globe) |> Path.wildcard
  end
end
