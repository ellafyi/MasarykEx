defmodule MasarykEx.Data.Backups.BackedUpMessagesTest do
  use ExUnit.Case, async: false

  alias MasarykEx.Data.Backups.BackedUpMessages

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MasarykEx.Repo)
  end

  defp upsert(overrides) do
    BackedUpMessages.upsert(
      Map.merge(
        %{
          message_id: "m#{System.unique_integer([:positive])}",
          channel_id: "c1",
          author_id: "u1"
        },
        Map.new(overrides)
      )
    )
  end

  test "upsert/1 dedupes on message_id" do
    assert {:ok, _} = BackedUpMessages.upsert(%{message_id: "dup", content: "first"})
    assert {:ok, _} = BackedUpMessages.upsert(%{message_id: "dup", content: "second"})
    assert BackedUpMessages.total() == 1
    # on_conflict: :nothing keeps the original
    assert BackedUpMessages.get_by_message("dup").content == "first"
  end

  test "full-text search matches content and honours filters" do
    upsert(message_id: "a", author_id: "u1", content: "the quick brown fox jumps")
    upsert(message_id: "b", author_id: "u2", content: "lazy dogs sleeping")

    assert ["a"] = BackedUpMessages.search(query: "fox") |> Enum.map(& &1.message_id)
    assert BackedUpMessages.count(query: "dogs") == 1
    assert BackedUpMessages.search(query: "fox", author_id: "u2") == []
    assert BackedUpMessages.search(query: "nonexistentword") == []
  end

  test "blank query lists everything newest-first with pagination" do
    base = ~U[2026-01-01 00:00:00Z]

    for n <- 1..3 do
      upsert(message_id: "p#{n}", posted_at: DateTime.add(base, n, :hour))
    end

    assert ["p3"] = BackedUpMessages.search(limit: 1) |> Enum.map(& &1.message_id)
    assert ["p2"] = BackedUpMessages.search(limit: 1, offset: 1) |> Enum.map(& &1.message_id)
    assert BackedUpMessages.count([]) == 3
  end

  test "mark_edited updates content; mark_deleted soft-deletes" do
    upsert(message_id: "e1", content: "original")

    BackedUpMessages.mark_edited("e1", %{content: "changed", edited_at: ~U[2026-02-02 00:00:00Z]})
    edited = BackedUpMessages.get_by_message("e1")
    assert edited.content == "changed"
    assert edited.edited_at == ~U[2026-02-02 00:00:00Z]

    BackedUpMessages.mark_deleted("e1")
    assert BackedUpMessages.get_by_message("e1").deleted_at != nil
  end

  test "edit/delete on an unknown message are no-ops" do
    assert {0, nil} = BackedUpMessages.mark_edited("ghost", %{content: "x"})
    assert {0, nil} = BackedUpMessages.mark_deleted("ghost")
  end
end
