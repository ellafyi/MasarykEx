defmodule MasarykEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :masaryk_ex,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {MasarykEx.Application, []}
    ]
  end

  defp deps do
    [
      # Not auto-started: the app starts nostrum itself only when Discord is
      # enabled, so the CLI and tests run without a bot token.
      {:nostrum, "~> 0.10", runtime: false},
      {:ecto_sql, "~> 3.12"},
      {:postgrex, "~> 0.19"},
      {:req, "~> 0.5"},
      {:floki, "~> 0.38.3"},
      {:codepagex, "~> 0.1"},
      {:phoenix_pubsub, "~> 2.1"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
