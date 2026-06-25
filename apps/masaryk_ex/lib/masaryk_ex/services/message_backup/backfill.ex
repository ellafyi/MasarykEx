defmodule MasarykEx.Services.MessageBackup.Backfill do
  @moduledoc """
  The history-walk logic behind the backup, kept separate from the `Backfiller`
  GenServer so it can be driven synchronously. Each `step/0` archives one
  oldest-first 100-message batch for the next unfinished channel, advancing a
  resumable per-channel cursor. Discord calls go through injectable functions
  (the `MasarykEx.Discord` pattern) so tests can drive it without a gateway.
  """

  alias MasarykEx.Adapters.Discord.Translate
  alias MasarykEx.Data.Backups.{BackedUpMessages, BackupChannels}

  require Logger

  @batch 100
  # GUILD_TEXT, GUILD_ANNOUNCEMENT, public/private threads, GUILD_FORUM
  @text_types [0, 5, 11, 12, 15]

  @doc "Discover the guild's text channels and register them for backfill."
  @spec inventory() :: :ok | :error
  def inventory do
    with guild when not is_nil(guild) <- guild_id(),
         {:ok, channels} <- channels_fetcher().(guild) do
      channels
      |> Enum.filter(&(&1.type in @text_types))
      |> Enum.map(&%{channel_id: to_string(&1.id), name: &1.name})
      |> BackupChannels.upsert_many()
    else
      _ -> :error
    end
  end

  @doc """
  Archive one batch for the next unfinished channel. Returns `{:progressed,
  channel}`, `{:channel_done, channel}` (caught up to the present), `:done` (no
  channels left), or `{:error, channel}`.
  """
  @spec step() ::
          {:progressed, struct()} | {:channel_done, struct()} | {:error, struct()} | :done
  def step do
    case BackupChannels.next_pending() do
      nil -> :done
      channel -> step_channel(channel)
    end
  end

  defp step_channel(channel) do
    locator = {:after, to_integer(channel.after_cursor)}

    case history_fetcher().(to_integer(channel.channel_id), @batch, locator) do
      {:ok, [_ | _] = messages} ->
        Enum.each(
          messages,
          &BackedUpMessages.upsert(Translate.to_event(:MESSAGE_CREATE, &1).data)
        )

        max_id = messages |> Enum.map(& &1.id) |> Enum.max()
        BackupChannels.save_cursor(channel.channel_id, to_string(max_id), length(messages))

        if length(messages) < @batch do
          BackupChannels.mark_done(channel.channel_id)
          {:channel_done, channel}
        else
          {:progressed, channel}
        end

      {:ok, []} ->
        BackupChannels.mark_done(channel.channel_id)
        {:channel_done, channel}

      error ->
        Logger.warning("[Backfill] channel #{channel.channel_id} fetch failed: #{inspect(error)}")
        {:error, channel}
    end
  end

  defp guild_id, do: Application.get_env(:masaryk_ex, :discord_guild_id)

  defp channels_fetcher do
    Application.get_env(:masaryk_ex, :backup_channels_fetcher, &Nostrum.Api.Guild.channels/1)
  end

  defp history_fetcher do
    Application.get_env(:masaryk_ex, :backup_history_fetcher, &Nostrum.Api.Channel.messages/3)
  end

  defp to_integer(value) when is_integer(value), do: value
  defp to_integer(value) when is_binary(value), do: String.to_integer(value)
end
