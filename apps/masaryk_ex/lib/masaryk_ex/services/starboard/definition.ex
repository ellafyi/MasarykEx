defmodule MasarykEx.Services.Starboard.Definition do
  @moduledoc """
  Reposts a message to a configured channel once a single emoji's reaction count
  reaches the threshold, then keeps that count current as reactions are added or
  removed. The post happens once (deduped by source message id); later changes
  edit the existing starboard post rather than posting again. Reactions in the
  starboard channel itself are ignored to avoid a feedback loop.
  """

  use MasarykEx.Core.Service

  alias MasarykEx.Adapters.Discord.Outbound
  alias MasarykEx.Core.Event
  alias MasarykEx.Data.Starboard.StarredMessages

  require Logger

  @topic "starboard"

  @impl true
  def config_schema, do: %{threshold: 3, channel_id: nil}

  @impl true
  def handle_event(%Event{type: type} = event, config)
      when type in [:reaction_added, :reaction_removed] do
    process(event, config)
    :ok
  end

  def handle_event(_event, _config), do: :ok

  defp process(%Event{data: data, context: context}, config) do
    channel_id = blank_to_nil(config[:channel_id])

    cond do
      is_nil(channel_id) ->
        :ok

      data.channel_id == channel_id ->
        :ok

      true ->
        with {:ok, message} <- Outbound.get_message(data.channel_id, data.message_id) do
          count = Outbound.count_for_emoji(message, data.emoji_name)
          reconcile(data, context, config, channel_id, message, count)
        else
          :error ->
            Logger.debug("[Starboard] could not fetch message #{data.message_id}")
            :ok
        end
    end
  end

  defp reconcile(data, context, config, channel_id, message, count) do
    case StarredMessages.get_by_message(data.message_id) do
      nil ->
        if count >= config[:threshold] do
          post_new(data, context, channel_id, message, count)
        end

      %{emoji: emoji} = entry when emoji == data.emoji_name ->
        update_existing(entry, channel_id, count)

      _other_emoji ->
        :ok
    end
  end

  defp post_new(data, context, channel_id, message, count) do
    attrs = %{
      message_id: data.message_id,
      channel_id: data.channel_id,
      guild_id: context.guild_id,
      author: author(message),
      content: content(message),
      emoji: data.emoji_name,
      reaction_count: count
    }

    with {:ok, posted} <- Outbound.create_message(channel_id, Outbound.starboard_embed(attrs)),
         {:ok, _entry} <-
           StarredMessages.create(Map.put(attrs, :starboard_message_id, id_string(posted))) do
      broadcast()
    else
      error ->
        Logger.warning("[Starboard] failed to post message #{data.message_id}: #{inspect(error)}")
        :ok
    end
  end

  defp update_existing(entry, channel_id, count) do
    embed =
      Outbound.starboard_embed(%{
        author: entry.author,
        content: entry.content,
        guild_id: entry.guild_id,
        channel_id: entry.channel_id,
        message_id: entry.message_id,
        emoji: entry.emoji,
        reaction_count: count
      })

    if entry.starboard_message_id do
      Outbound.edit_message(channel_id, entry.starboard_message_id, embed)
    end

    case StarredMessages.update(entry, %{reaction_count: count}) do
      {:ok, _} -> broadcast()
      _ -> :ok
    end
  end

  defp author(%{author: %{username: username}}), do: username
  defp author(_), do: nil

  defp content(%{content: content}), do: content
  defp content(_), do: nil

  defp id_string(%{id: id}) when not is_nil(id), do: to_string(id)
  defp id_string(_), do: nil

  defp broadcast do
    Phoenix.PubSub.broadcast(MasarykEx.PubSub, @topic, {:starboard, :updated})
    :ok
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
