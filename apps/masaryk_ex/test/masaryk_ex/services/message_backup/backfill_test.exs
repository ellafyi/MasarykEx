defmodule MasarykEx.Services.MessageBackup.BackfillTest do
  use ExUnit.Case, async: false

  alias MasarykEx.Data.Backups.{BackedUpMessages, BackupChannels}
  alias MasarykEx.Services.MessageBackup.{Backfill, Backfiller}

  # Channel -> total historical messages (ids 1..total).
  @totals %{111 => 150, 222 => 30}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MasarykEx.Repo)
    Application.put_env(:masaryk_ex, :discord_guild_id, 1)

    Application.put_env(:masaryk_ex, :backup_channels_fetcher, fn 1 ->
      {:ok,
       [
         %{id: 111, type: 0, name: "general"},
         %{id: 222, type: 0, name: "random"},
         %{id: 333, type: 2, name: "Voice"}
       ]}
    end)

    # Mimic Discord's `after` pagination: the oldest <=100 messages with id > after.
    Application.put_env(:masaryk_ex, :backup_history_fetcher, fn channel,
                                                                 100,
                                                                 {:after, after_id} ->
      batch =
        1..Map.fetch!(@totals, channel)
        |> Enum.map(&message(channel, &1))
        |> Enum.filter(&(&1.id > after_id))
        |> Enum.take(100)

      {:ok, batch}
    end)

    on_exit(fn ->
      for k <- [:discord_guild_id, :backup_channels_fetcher, :backup_history_fetcher],
          do: Application.delete_env(:masaryk_ex, k)
    end)

    :ok
  end

  defp message(channel, n) do
    # Globally-unique ids (real Discord ids never repeat across channels).
    %{
      id: channel * 1_000_000 + n,
      channel_id: channel,
      guild_id: 1,
      content: "message #{n}",
      author: %{id: 9, username: "bob"},
      timestamp: ~U[2026-01-01 00:00:00Z],
      edited_timestamp: nil,
      type: 0,
      pinned: false,
      attachments: []
    }
  end

  test "inventory registers only text channels" do
    assert :ok = Backfill.inventory()
    assert %{total: 2, done: 0} = BackupChannels.progress()
    assert BackupChannels.next_pending().channel_id == "111"
  end

  test "step archives a full batch and advances the cursor" do
    Backfill.inventory()

    assert {:progressed, _} = Backfill.step()
    assert BackedUpMessages.total() == 100

    channel = BackupChannels.next_pending()
    assert channel.channel_id == "111"
    assert channel.after_cursor == "111000100"
    assert channel.message_count == 100
  end

  test "a short final batch marks the channel done" do
    Backfill.inventory()
    Backfill.step()
    assert {:channel_done, _} = Backfill.step()
    assert BackupChannels.next_pending().channel_id == "222"
  end

  test "driving to completion archives every channel's history oldest-first" do
    Backfill.inventory()
    assert :done = drain()

    assert BackedUpMessages.total() == 180
    assert %{total: 2, done: 2} = BackupChannels.progress()
    assert BackupChannels.next_pending() == nil
    # oldest-first: the smallest id in channel 111 maps to its first message
    assert BackedUpMessages.get_by_message("111000001").content == "message 1"
  end

  test "a paused Backfiller does not fetch or step" do
    Application.put_env(:masaryk_ex, :backup_history_fetcher, fn _c, _l, _loc ->
      send(self(), :fetched)
      {:ok, []}
    end)

    assert {:noreply, %{running: false}} = Backfiller.handle_info(:work, %{running: false})
    refute_received :fetched
  end

  defp drain do
    case Backfill.step() do
      :done -> :done
      _ -> drain()
    end
  end
end
