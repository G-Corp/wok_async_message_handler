defmodule Mix.Tasks.WokAsyncMessageHandler.Init do
  use Mix.Task
  import Mix.Generator

  @shortdoc "Create migration files for Ecto"

  def run(_) do
    host_app_main_repo = Mix.Ecto.parse_repo([]) |> List.first
    migrations_path = Path.join("priv/#{host_app_main_repo |> Module.split |> List.last |> Macro.underscore}", "migrations")
    create_directory(migrations_path)
    file = Path.join(migrations_path, "#{timestamp()}_add_ecto_producer_message.exs")
    create_file file, migration_template([host_app_main_repo: host_app_main_repo])
    file = Path.join(migrations_path, "#{timestamp()}_add_ecto_producer_stopped_partitions.exs")
    create_file file, stopped_paritions_template([host_app_main_repo: host_app_main_repo])
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

  embed_template :stopped_paritions, """
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
end