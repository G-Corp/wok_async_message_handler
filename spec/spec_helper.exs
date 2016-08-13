ESpec.configure fn(config) ->
  Application.ensure_started(:postgrex)
  Application.ensure_started(:ecto)
  WokAsyncMessageHandler.Repo.start_link

  config.before fn(_tags) ->
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(WokAsyncMessageHandler.Repo)
  end

  config.finally fn(_shared) ->
    :ok = Ecto.Adapters.SQL.Sandbox.checkin(WokAsyncMessageHandler.Repo)
  end
end

Ecto.Adapters.SQL.Sandbox.mode(WokAsyncMessageHandler.Repo, :manual)
