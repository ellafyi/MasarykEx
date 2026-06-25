defmodule MasarykEx.Data.Backups.BackupChannels do
  @moduledoc "Per-channel backfill progress: the resumable cursor and done flag."

  import Ecto.Query

  alias MasarykEx.Repo
  alias MasarykEx.Data.Backups.BackupChannel

  @doc "Register channels for backfill, refreshing names but never resetting cursors."
  @spec upsert_many([map()]) :: :ok
  def upsert_many(channels) do
    Enum.each(channels, fn attrs ->
      %BackupChannel{}
      |> BackupChannel.changeset(attrs)
      |> Repo.insert(
        on_conflict: [set: [name: attrs[:name], updated_at: now()]],
        conflict_target: :channel_id
      )
    end)
  end

  @doc "The next channel still needing backfill, or nil when all are done."
  @spec next_pending() :: BackupChannel.t() | nil
  def next_pending do
    from(c in BackupChannel, where: c.done == false, order_by: [asc: c.id], limit: 1)
    |> Repo.one()
  end

  @doc "Advance a channel's cursor and add to its archived count."
  @spec save_cursor(String.t(), String.t(), non_neg_integer()) :: {non_neg_integer(), nil}
  def save_cursor(channel_id, after_cursor, added) do
    from(c in BackupChannel, where: c.channel_id == ^channel_id)
    |> Repo.update_all(
      set: [after_cursor: after_cursor, last_run_at: now(), updated_at: now()],
      inc: [message_count: added]
    )
  end

  @doc "Mark a channel fully backfilled (caught up to the present)."
  @spec mark_done(String.t()) :: {non_neg_integer(), nil}
  def mark_done(channel_id) do
    from(c in BackupChannel, where: c.channel_id == ^channel_id)
    |> Repo.update_all(set: [done: true, last_run_at: now(), updated_at: now()])
  end

  @doc "Backfill progress as `%{total: channels, done: completed}`."
  @spec progress() :: %{total: non_neg_integer(), done: non_neg_integer()}
  def progress do
    %{
      total: Repo.aggregate(BackupChannel, :count, :id),
      done: Repo.aggregate(from(c in BackupChannel, where: c.done == true), :count, :id)
    }
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
