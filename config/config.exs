import Config

config :codepagex, :encodings, ["VENDORS/MICSFT/WINDOWS/CP1250"]

config :masaryk_ex,
  ecto_repos: [MasarykEx.Repo],
  discord_enabled: true

# Static per-feature defaults can live here, e.g.:
#   config :masaryk_ex, MasarykEx.Commands.RestaurantMenus.Definition, restaurants: ["A", "B"]

import_config "#{config_env()}.exs"
