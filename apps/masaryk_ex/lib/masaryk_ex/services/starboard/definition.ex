defmodule MasarykEx.Services.Starboard.Definition do
  @moduledoc """
  Routes a reacted message to exactly one user-defined starboard once a single
  emoji's reaction count reaches that board's threshold, then keeps the count
  current as reactions change. The board is chosen by the message's membership
  channel (a thread inherits its parent's board and the thread/forum threshold);
  most-specific wins. The post happens once per source message (deduped by
  message id); later changes edit the existing post. Reactions in any board's
  own target channel are ignored to avoid a feedback loop.
  """

  use MasarykEx.Core.Service

  alias MasarykEx.Adapters.Discord.Outbound
  alias MasarykEx.Core.Event
  alias MasarykEx.Data.Starboard.Starboards
  alias MasarykEx.Data.Starboard.StarredMessages
  alias MasarykEx.Services.Starboard.Routing

  require Logger

  @topic "starboard"

  # Thread (10/11/12) and forum (15) sources are matched by their parent channel
  # and use the board's thread threshold; everything else routes by its own id.
  @thread_types [10, 11, 12]

  @impl true
  def config_schema, do: %{}

  @impl true
  def handle_event(%Event{type: type} = event, _config)
      when type in [:reaction_added, :reaction_removed] do
    process(event)
    :ok
  end

  def handle_event(_event, _config), do: :ok

  defp process(%Event{data: data, context: context}) do
    boards =
      context.guild_id
      |> Starboards.for_guild()
      |> Enum.filter(& &1.enabled)

    cond do
      boards == [] -> :ok
      Routing.target_channel?(boards, data.channel_id) -> :ok
      true -> route(data, context, boards)
    end
  end

  defp route(data, context, boards) do
    {thread?, membership_channel} = membership(data.channel_id)

    case Routing.select(boards, membership_channel) do
      nil ->
        :ok

      board ->
        threshold = if thread?, do: board.thread_threshold, else: board.threshold

        with {:ok, message} <- Outbound.get_message(data.channel_id, data.message_id) do
          count = Outbound.count_for_emoji(message, data.emoji_name)
          reconcile(data, context, board, threshold, message, count)
        else
          :error ->
            Logger.debug("[Starboard] could not fetch message #{data.message_id}")
            :ok
        end
    end
  end

  # Membership channel: a thread/forum's parent (so a thread inherits its
  # parent's board), otherwise the source channel itself. Falls back to the
  # source channel as a normal channel when the channel can't be resolved.
  defp membership(channel_id) do
    case Outbound.channel_info(channel_id) do
      {:ok, %{type: type, parent_id: parent_id}} when type in @thread_types ->
        {true, parent_id || channel_id}

      _ ->
        {false, channel_id}
    end
  end

  defp reconcile(data, context, board, threshold, message, count) do
    case StarredMessages.get_by_message(data.message_id) do
      nil ->
        if count >= threshold do
          post_new(data, context, board, message, count)
        end

      %{emoji: emoji} = entry when emoji == data.emoji_name ->
        update_existing(entry, board.target_channel_id, count)

      _other_emoji ->
        :ok
    end
  end

  defp post_new(data, context, board, message, count) do
    media = Outbound.media(message)

    attrs = %{
      message_id: data.message_id,
      channel_id: data.channel_id,
      guild_id: context.guild_id,
      author: author(message),
      content: content(message),
      emoji: data.emoji_name,
      reaction_count: count,
      media_url: media && media.url,
      media_type: media && Atom.to_string(media.type),
      emoji_id: Map.get(data, :emoji_id),
      emoji_animated: Map.get(data, :emoji_animated, false),
      author_avatar_url: Outbound.author_avatar_url(message),
      starboard_id: board.id
    }

    with {:ok, posted} <-
           Outbound.create_message(board.target_channel_id, Outbound.starboard_embed(attrs)),
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
        reaction_count: count,
        media_url: entry.media_url,
        media_type: entry.media_type,
        emoji_id: entry.emoji_id,
        emoji_animated: entry.emoji_animated,
        author_avatar_url: entry.author_avatar_url
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
end
