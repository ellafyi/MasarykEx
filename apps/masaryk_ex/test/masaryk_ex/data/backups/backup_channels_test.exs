defmodule MasarykEx.Data.Backups.BackupChannelsTest do
  use ExUnit.Case, async: false

  alias MasarykEx.Data.Backups.BackupChannels

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MasarykEx.Repo)
  end

  test "upsert_many registers channels and refreshes names without resetting cursors" do
    BackupChannels.upsert_many([%{channel_id: "c1", name: "general"}])
    BackupChannels.save_cursor("c1", "500", 100)

    BackupChannels.upsert_many([
      %{channel_id: "c1", name: "renamed"},
      %{channel_id: "c2", name: "off-topic"}
    ])

    pending = BackupChannels.next_pending()
    assert pending.channel_id == "c1"
    assert pending.name == "renamed"
    assert pending.after_cursor == "500"
    assert pending.message_count == 100
  end

  test "save_cursor advances the cursor and accumulates counts" do
    BackupChannels.upsert_many([%{channel_id: "c1", name: "general"}])

    BackupChannels.save_cursor("c1", "100", 50)
    BackupChannels.save_cursor("c1", "200", 30)

    assert BackupChannels.next_pending().after_cursor == "200"
    assert BackupChannels.next_pending().message_count == 80
  end

  test "mark_done removes a channel from the pending queue and counts toward progress" do
    BackupChannels.upsert_many([%{channel_id: "c1", name: "a"}, %{channel_id: "c2", name: "b"}])

    BackupChannels.mark_done("c1")

    assert BackupChannels.next_pending().channel_id == "c2"
    assert BackupChannels.progress() == %{total: 2, done: 1}

    BackupChannels.mark_done("c2")
    assert BackupChannels.next_pending() == nil
    assert BackupChannels.progress() == %{total: 2, done: 2}
  end
end
