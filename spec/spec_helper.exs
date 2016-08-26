ESpec.configure fn(config) ->
  Application.ensure_started(:postgrex)
  Application.ensure_started(:ecto)
  WokAsyncMessageHandler.Spec.Repo.start_link

  config.before fn(tags) ->
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(WokAsyncMessageHandler.Spec.Repo)
    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(WokAsyncMessageHandler.Spec.Repo, {:shared, self()})
    end
  end

  config.finally fn(_shared) ->
    :ok = Ecto.Adapters.SQL.Sandbox.checkin(WokAsyncMessageHandler.Spec.Repo)
  end
end
