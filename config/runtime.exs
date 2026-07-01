import Config

# Load .env in dev
if config_env() == :dev and File.exists?(".env") do
  File.stream!(".env")
  |> Stream.map(&String.trim/1)
  |> Stream.reject(&(String.starts_with?(&1, "#") or &1 == ""))
  |> Enum.each(fn line ->
    [key, val] = String.split(line, "=", parts: 2)
    System.put_env(String.trim(key), String.trim(val, "\""))
  end)
end

# Database (test is configured in test.exs)
if config_env() != :test do
  if url = System.get_env("DATABASE_URL") do
    config :masaryk_ex, MasarykEx.Repo, url: url
  else
    config :masaryk_ex, MasarykEx.Repo,
      username: System.get_env("PGUSER", "postgres"),
      password: System.get_env("PGPASSWORD", "postgres"),
      hostname: System.get_env("PGHOST", "localhost"),
      port: String.to_integer(System.get_env("PGPORT", "5433")),
      database: System.get_env("PGDATABASE", "masaryk_ex_#{config_env()}")
  end

  config :masaryk_ex, MasarykEx.Repo,
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))
end

# Discord is enabled only when a token is present and not explicitly disabled,
# so the CLI and tests run fine without one.
bot_token = System.get_env("BOT_TOKEN")

discord_enabled =
  System.get_env("DISCORD_ENABLED", "true") != "false" and bot_token not in [nil, ""]

config :masaryk_ex, discord_enabled: discord_enabled

if discord_enabled do
  config :nostrum,
    token: bot_token,
    gateway_intents: [
      :guilds,
      :guild_members,
      :guild_messages,
      :guild_message_typing,
      :guild_message_reactions,
      :direct_messages,
      :direct_message_reactions,
      :message_content
    ]

  if guild_id = System.get_env("DISCORD_GUILD_ID") do
    config :masaryk_ex, :discord_guild_id, String.to_integer(guild_id)
  end
end

config :masaryk_ex, MasarykEx.Discord.OAuth,
  client_id: System.get_env("DISCORD_CLIENT_ID"),
  client_secret: System.get_env("DISCORD_CLIENT_SECRET"),
  redirect_uri:
    System.get_env("DISCORD_REDIRECT_URI", "http://localhost:4000/auth/discord/callback")

if role_id = System.get_env("STATS_ROLE_ID") do
  config :masaryk_ex, :stats_role_id, String.to_integer(role_id)
end

if secret = System.get_env("SECRET_KEY_BASE") do
  port = String.to_integer(System.get_env("PORT", "4000"))

  # Behind the Kamal/Cloudflare TLS proxy a PHX_HOST means we're served over https
  # on 443 (so generated URLs and LiveView origin checks are correct); without it
  # (e.g. local docker-compose) fall back to plain http on PORT.
  url =
    case System.get_env("PHX_HOST") do
      nil -> [host: "localhost", port: port]
      host -> [host: host, scheme: "https", port: 443]
    end

  config :masaryk_ex_web, MasarykExWeb.Endpoint,
    http: [ip: {0, 0, 0, 0}, port: port],
    url: url,
    secret_key_base: secret,
    server: true
end
