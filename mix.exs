defmodule WokAsyncMessageHandler.Mixfile do
  use Mix.Project

  def project do
    [
      app: :wok_async_message_handler,
      build_embedded: Mix.env == :prod,
      deps: deps(),
      elixir: "~> 1.2",
      elixirc_paths: elixirc_paths(Mix.env),
      preferred_cli_env: [espec: :test],
      start_permanent: Mix.env == :prod,
      test_coverage: [tool: ExCoveralls, test_task: "espec"],
      version: "0.2.2",
      elixirc_options: [warnings_as_errors: true],
      aliases: [
        "espec": ["ecto.drop --quiet", "ecto.create --quiet", "ecto.migrate", "espec"],
      ]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :postgrex, :ecto]]
  end

  defp elixirc_paths(:test), do: ["spec"] ++ elixirc_paths(:dev)
  defp elixirc_paths(_env), do: ["lib", "web"]

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:espec, "~> 1.2.2", only: :test},
      {:postgrex, ">= 0.0.0"},
      {:ecto, "~> 2.0"},
      {:poison, ">= 0.0.0"},
      {:wok, git: "git@gitlab.botsunit.com:msaas/wok.git", tag: "0.7.1"},
    ]
  end
end
