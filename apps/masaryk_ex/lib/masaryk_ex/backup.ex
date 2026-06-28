defmodule MasarykEx.Backup do
  @moduledoc """
  Dashboard-facing facade over the message archive: start/pause the historical
  backfill, read progress, search the archive, and manage the activity-log
  channel setting. Settings go through `Config.Store` at the global scope (the
  same mechanism `/config` uses), so the live-capture service picks them up with
  no restart.
  """

  alias MasarykEx.Config
  alias MasarykEx.Config.Store
  alias MasarykEx.Core.Context
  alias MasarykEx.Data.Backups.{BackedUpMessages, BackupChannels}
  alias MasarykEx.Services.MessageBackup.{Backfiller, Definition}

  @topic "backup"
  @web_context %Context{interface: :web}

  @doc "PubSub topic carrying backup progress/settings updates."
  @spec topic() :: String.t()
  def topic, do: @topic

  @doc "Start (or resume) the historical backfill."
  @spec start() :: :ok
  def start, do: Backfiller.start()

  @doc "Pause the historical backfill (live capture keeps running)."
  @spec pause() :: :ok
  def pause, do: Backfiller.pause()

  @doc "Whether the backfill is currently running."
  @spec running?() :: boolean()
  def running?, do: Backfiller.running?()

  @doc "Backfill progress as `%{total: channels, done: completed}`."
  @spec progress() :: %{total: non_neg_integer(), done: non_neg_integer()}
  def progress, do: BackupChannels.progress()

  @doc "Total archived messages."
  @spec total() :: non_neg_integer()
  def total, do: BackedUpMessages.total()

  @doc "Approximate total archived messages (planner estimate, O(1))."
  @spec estimated_total() :: non_neg_integer()
  def estimated_total, do: BackedUpMessages.estimated_total()

  @doc "The channel currently being backfilled, or nil."
  @spec current_channel() :: BackupChannels.BackupChannel.t() | nil
  def current_channel, do: BackupChannels.next_pending()

  @doc "Search the archive (see `BackedUpMessages.search/1` options)."
  @spec search(keyword()) :: [BackedUpMessages.BackedUpMessage.t()]
  def search(opts), do: BackedUpMessages.search(opts)

  @doc "Number of archived messages matching the search options."
  @spec count(keyword()) :: non_neg_integer()
  def count(opts), do: BackedUpMessages.count(opts)

  @doc "Current settings (the activity-log channel)."
  @spec settings() :: %{channel_id: String.t() | nil}
  def settings, do: %{channel_id: Config.get(Definition, :channel_id, @web_context)}

  @doc "Persist the activity-log channel and broadcast the change."
  @spec update_settings(%{channel_id: String.t() | nil}) :: :ok | {:error, term()}
  def update_settings(%{channel_id: channel_id}) do
    with :ok <- Store.put(inspect(Definition), "channel_id", "global", channel_id) do
      Phoenix.PubSub.broadcast(MasarykEx.PubSub, @topic, {:backup, :settings})
      :ok
    end
  end
end
