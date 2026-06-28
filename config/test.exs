import Config

# Don't open a Discord gateway connection during tests.
config :masaryk_ex, discord_enabled: false

config :masaryk_ex, MasarykEx.Repo,
  username: System.get_env("PGUSER", "postgres"),
  password: System.get_env("PGPASSWORD", "postgres"),
  hostname: System.get_env("PGHOST", "localhost"),
  port: String.to_integer(System.get_env("PGPORT", "5432")),
  database: "masaryk_ex_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :logger, level: :warning

config :masaryk_ex_web, MasarykExWeb.Endpoint,
  server: false,
  secret_key_base: String.duplicate("a", 64)
