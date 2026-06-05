defmodule MasarykEx.Services.EventLogger do
  @moduledoc """
  Example passive service that logs select Discord events.
  Drop more services in `lib/masaryk_ex/services/` and they attach
  automatically without touching the consumer.
  """

  @behaviour MasarykEx.Service

  require Logger

  @impl true
  def handle_event(:MESSAGE_CREATE, msg, _ws) do
    Logger.debug("[EventLogger] ##{msg.channel_id} <#{msg.author.username}>: #{msg.content}")
    :ok
  end

  def handle_event(:MESSAGE_REACTION_ADD, reaction, _ws) do
    Logger.debug("[EventLogger] Reaction #{reaction.emoji.name} on msg #{reaction.message_id}")
    :ok
  end

  def handle_event(_type, _payload, _ws) do
    :ok
  end
end
