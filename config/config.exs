import Config

config :masaryk_ex,
  ecto_repos: [MasarykEx.Repo],
  discord_enabled: true

# Static per-feature defaults can live here, e.g.:
#   config :masaryk_ex, MasarykEx.Commands.RestaurantMenus, restaurants: ["A", "B"]

import_config "#{config_env()}.exs"
