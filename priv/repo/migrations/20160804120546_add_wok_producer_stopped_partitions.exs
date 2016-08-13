defmodule WokAsyncMessageHandler.PG.Migrations.AddWokProducerStoppedPartitions do
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
