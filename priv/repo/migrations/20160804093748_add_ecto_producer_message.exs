defmodule WokAsyncMessageHandler.Repo.Migrations.AddEctoProducerMessage do
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
