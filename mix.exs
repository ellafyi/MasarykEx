defmodule MasarykEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :masaryk_ex,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      releases: releases(),
      deps: deps()
    ]
  end

  # nostrum is `runtime: false` so it doesn't auto-start (and demand a token) in
  # dev/test/CLI. Include it in releases as a loaded-but-not-started app; the
  # application starts it itself only when Discord is enabled.
  defp releases do
    [
      masaryk_ex: [
        applications: [nostrum: :load]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {MasarykEx.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Not auto-started: the app starts nostrum itself only when Discord is
      # enabled, so the CLI and tests run without a bot token.
      {:nostrum, "~> 0.10", runtime: false},
      {:ecto_sql, "~> 3.12"},
      {:postgrex, "~> 0.19"},
      {:req, "~> 0.5"},
      {:floki, "~> 0.38.3"}
    ]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"]
    ]
  end
end
