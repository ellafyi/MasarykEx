defmodule MasarykEx.Services.EventLogger do
  @moduledoc "Passive service that logs select events."

  use MasarykEx.Core.Service

  alias MasarykEx.Core.Event

  require Logger

  @impl true
  def handle_event(%Event{type: :message_created, data: data}, _config) do
    Logger.debug("[EventLogger] ##{data.channel_id} <#{data.author_username}>: #{data.content}")
    :ok
  end

  def handle_event(%Event{type: :reaction_added, data: data}, _config) do
    Logger.debug("[EventLogger] Reaction #{data.emoji_name} on msg #{data.message_id}")
    :ok
  end

  def handle_event(_event, _config), do: :ok
end
