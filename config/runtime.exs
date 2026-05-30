import Config

# Automatically load .env in dev
if config_env() == :dev and File.exists?(".env") do
  File.stream!(".env")
  |> Stream.map(&String.trim/1)
  |> Stream.reject(&(String.starts_with?(&1, "#") or &1 == ""))
  |> Enum.each(fn line ->
    [key, val] = String.split(line, "=", parts: 2)
    System.put_env(String.trim(key), String.trim(val, "\""))
  end)
end

bot_token = System.get_env("BOT_TOKEN") ||
  raise "Environment variable BOT_TOKEN is missing. Set it in your .env file or shell."

config :nostrum,
  token: bot_token,
  gateway_intents: [:direct_messages, :guild_messages, :message_content]
