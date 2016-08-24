ESpec.configure fn(config) ->
  Application.ensure_started(:postgrex)
  Application.ensure_started(:ecto)
  WokAsyncMessageHandler.Repo.start_link

  config.before fn(tags) ->
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(WokAsyncMessageHandler.Repo)
    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(WokAsyncMessageHandler.Repo, {:shared, self()})
    end
  end

  config.finally fn(_shared) ->
    :ok = Ecto.Adapters.SQL.Sandbox.checkin(WokAsyncMessageHandler.Repo)
  end
end
