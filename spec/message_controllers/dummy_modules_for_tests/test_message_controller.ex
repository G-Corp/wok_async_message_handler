defmodule TestMessageController do
  @message_version 1
  @datastore WokAsyncMessageHandler.Spec.Repo
  @model WokAsyncMessageHandler.Models.StoppedPartition #just for test, to not generate a new model
  @keys_mapping %{"field_to_remap" => :error}
  @master_key nil
  use WokAsyncMessageHandler.MessageControllers.Base

  def before_create(attributes) do
    __MODULE__.test_before_create()
    attributes
  end

  def test_before_create, do: nil

  def after_create(struct) do
    __MODULE__.test_after_create()
    {:ok, struct}
  end

  def test_after_create, do: nil

  def after_destroy(struct) do
    __MODULE__.test_callback()
    {:ok, struct}
  end

  def test_callback, do: :ok

  def before_update(attributes) do
    __MODULE__.test_before_update()
    attributes
  end

  def test_before_update, do: :ok

  def after_update(struct) do
    __MODULE__.test_after_update()
    {:ok, struct}
  end

  def test_after_update, do: :ok
end

defmodule TestMessageControllerWithMasterKey do
  @message_version 1
  @datastore WokAsyncMessageHandler.Spec.Repo
  @model WokAsyncMessageHandler.Models.StoppedPartition #just for test, to not generate a new model
  @keys_mapping %{"field_to_remap" => :error}
  @master_key {:message_id, "pmessage_id"}
  use WokAsyncMessageHandler.MessageControllers.Base
end