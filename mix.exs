defmodule MasarykEx.Umbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      releases: releases()
    ]
  end

  # nostrum is runtime: false so it doesn't auto-start (and demand a token) in
  # dev/test/CLI. Include it in releases as a loaded-but-not-started app; the
  # bot application starts it only when Discord is enabled.
  defp releases do
    [
      masaryk_ex: [
        applications: [masaryk_ex: :permanent, masaryk_ex_web: :permanent, nostrum: :load]
      ]
    ]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"]
    ]
  end
end
