defmodule TestMessageController do
  @message_version 1
  @datastore WokAsyncMessageHandler.Spec.Repo
  @model WokAsyncMessageHandler.Models.StoppedPartition #just for test, to not generate a new model
  @keys_mapping %{"field_to_remap" => :error}
  @master_key nil
  use WokAsyncMessageHandler.MessageControllers.Base

  def before_create(event_data) do
    __MODULE__.test_before_create(event_data)
    Map.put(event_data, :added_data, :my_bc_added_data)
  end
  def test_before_create(_event_data), do: nil

  def after_create(event_data) do
    __MODULE__.test_after_create(event_data)
    {:ok, event_data}
  end
  def test_after_create(_event_data), do: nil

  def after_create_transaction(event_data) do
    __MODULE__.test_after_create_transaction(event_data)
    {:ok, event_data}
  end
  def test_after_create_transaction(_event_data), do: :ok

  def before_destroy(event_data) do
    __MODULE__.test_before_destroy(event_data)
    Map.put(event_data, :added_data, :my_bd_added_data)
  end
  def test_before_destroy(_event_data), do: :ok

  def after_destroy(event_data) do
    __MODULE__.test_after_destroy(event_data)
    {:ok, event_data}
  end
  def test_after_destroy(_event_data), do: :ok

  def before_update(event_data) do
    __MODULE__.test_before_update(event_data)
    Map.put(event_data, :added_data, :my_bu_added_data)
  end
  def test_before_update(_event_data), do: :ok

  def after_update(event_data) do
    __MODULE__.test_after_update(event_data)
    {:ok, event_data}
  end
  def test_after_update(_event_data), do: :ok

  def after_update_transaction(event_data) do
    __MODULE__.test_after_update_transaction(event_data)
    {:ok, event_data}
  end
  def test_after_update_transaction(_event_data), do: :ok
end

defmodule TestMessageControllerWithMasterKey do
  @message_version 1
  @datastore WokAsyncMessageHandler.Spec.Repo
  @model WokAsyncMessageHandler.Models.StoppedPartition #just for test, to not generate a new model
  @keys_mapping %{"field_to_remap" => :error}
  @master_key {:message_id, "pmessage_id"}
  use WokAsyncMessageHandler.MessageControllers.Base
end