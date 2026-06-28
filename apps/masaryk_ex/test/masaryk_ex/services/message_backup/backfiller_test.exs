defmodule MasarykEx.Services.MessageBackup.BackfillerTest do
  use ExUnit.Case, async: false

  alias MasarykEx.Config.Store
  alias MasarykEx.Services.MessageBackup.{Backfill, Backfiller, Definition}

  @feature inspect(Definition)
  # Channel -> total historical messages (ids 1..total). 250 = 100 + 100 + 50.
  @totals %{111 => 250}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MasarykEx.Repo)
    # The Config.Store runs in its own process, so it needs the shared connection.
    Ecto.Adapters.SQL.Sandbox.mode(MasarykEx.Repo, {:shared, self()})

    # The config cache (ETS) is not transactional — clear any channel a prior test left.
    for scope <- ["global", "1"], do: Store.delete(@feature, "channel_id", scope)

    Application.put_env(:masaryk_ex, :discord_guild_id, 1)

    Application.put_env(:masaryk_ex, :backup_channels_fetcher, fn 1 ->
      {:ok, [%{id: 111, type: 0, name: "general"}]}
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

    test_pid = self()

    # Outbound.create_message posts through the :starboard_message_poster fn.
    Application.put_env(:masaryk_ex, :starboard_message_poster, fn channel, payload ->
      send(test_pid, {:posted, channel, payload})
      {:ok, %{id: 1}}
    end)

    on_exit(fn ->
      for k <- [
            :discord_guild_id,
            :backup_channels_fetcher,
            :backup_history_fetcher,
            :starboard_message_poster
          ],
          do: Application.delete_env(:masaryk_ex, k)
    end)

    :ok
  end

  defp message(channel, n) do
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

  defp state(overrides \\ %{}) do
    Map.merge(%{running: true, last_broadcast: 0, last_notify: 0}, overrides)
  end

  test ":resume announces a resume line to the configured channel" do
    Store.put(@feature, "channel_id", "global", "999")

    assert {:noreply, _state} = Backfiller.handle_info(:resume, state())

    assert_received {:posted, 999, %{content: content}}
    assert content =~ "Resuming"
  end

  test "notify is a no-op when no log channel is configured" do
    assert {:noreply, _state} = Backfiller.handle_info(:resume, state())

    refute_received {:posted, _, _}
  end

  test "a finished channel announces immediately" do
    Store.put(@feature, "channel_id", "global", "999")
    Backfill.inventory()
    # Drain the two full batches; the next step yields the short final batch.
    assert {:progressed, _} = Backfill.step()
    assert {:progressed, _} = Backfill.step()

    assert {:noreply, _state} = Backfiller.handle_info(:work, state())

    assert_received {:posted, 999, %{content: content}}
    assert content =~ "Backed up"
  end

  test "progress notifications are throttled across quick work steps" do
    Store.put(@feature, "channel_id", "global", "999")
    Backfill.inventory()

    # Make the first step due for a progress line; the immediate second step is not.
    old = System.monotonic_time(:millisecond) - 60_001
    {:noreply, s1} = Backfiller.handle_info(:work, state(%{last_notify: old}))
    {:noreply, _s2} = Backfiller.handle_info(:work, s1)

    assert_received {:posted, 999, %{content: first}}
    assert first =~ "Backing up"
    # The second step falls inside the throttle window → no further progress line.
    refute_received {:posted, _, %{content: _}}
  end

  test "a guild-scoped channel override resolves ahead of the global one" do
    Store.put(@feature, "channel_id", "global", "999")
    Store.put(@feature, "channel_id", "1", "777")

    assert {:noreply, _state} = Backfiller.handle_info(:resume, state())

    assert_received {:posted, 777, %{content: _}}
  end
end
