import Config

config :codepagex, :encodings, ["VENDORS/MICSFT/WINDOWS/CP1250"]

config :masaryk_ex,
  ecto_repos: [MasarykEx.Repo],
  discord_enabled: true

# Static per-feature defaults can live here, e.g.:
#   config :masaryk_ex, MasarykEx.Commands.RestaurantMenus.Definition, restaurants: ["A", "B"]

config :masaryk_ex_web, MasarykExWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  pubsub_server: MasarykEx.PubSub,
  live_view: [signing_salt: "YHlclDmS1lKFW4hV2PuQt6HfPsqUiERQ"]

config :masaryk_ex_web, :generators, context_app: :masaryk_ex

import_config "#{config_env()}.exs"
