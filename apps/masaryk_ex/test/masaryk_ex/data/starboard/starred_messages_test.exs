defmodule MasarykEx.Data.Starboard.StarredMessagesTest do
  use ExUnit.Case, async: false

  alias MasarykEx.Data.Starboard.StarredMessages

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MasarykEx.Repo)
  end

  defp attrs(overrides \\ %{}) do
    Map.merge(
      %{
        message_id: "1",
        channel_id: "100",
        guild_id: "9",
        author: "alice",
        emoji: "⭐",
        reaction_count: 3
      },
      overrides
    )
  end

  test "create/1 and get_by_message/1 round-trip" do
    assert {:ok, entry} = StarredMessages.create(attrs())
    assert entry.message_id == "1"

    fetched = StarredMessages.get_by_message("1")
    assert fetched.id == entry.id
    assert StarredMessages.get_by_message("nope") == nil
  end

  test "message_id is unique" do
    assert {:ok, _} = StarredMessages.create(attrs())
    assert {:error, changeset} = StarredMessages.create(attrs())
    assert "has already been taken" in errors_on(changeset, :message_id)
  end

  test "update/2 changes the reaction count" do
    {:ok, entry} = StarredMessages.create(attrs())
    assert {:ok, updated} = StarredMessages.update(entry, %{reaction_count: 7})
    assert updated.reaction_count == 7
  end

  test "list/1 returns newest first and honours limit/offset" do
    for n <- 1..3 do
      {:ok, _} = StarredMessages.create(attrs(%{message_id: "m#{n}"}))
    end

    assert StarredMessages.count() == 3

    [first] = StarredMessages.list(limit: 1)
    assert first.message_id == "m3"

    [second] = StarredMessages.list(limit: 1, offset: 1)
    assert second.message_id == "m2"
  end

  test "casts and persists emoji_id, emoji_animated and author_avatar_url" do
    {:ok, entry} =
      StarredMessages.create(
        attrs(%{
          emoji_id: "123",
          emoji_animated: true,
          author_avatar_url: "https://cdn.discordapp.com/avatars/42/abc.png"
        })
      )

    fetched = StarredMessages.get_by_message(entry.message_id)
    assert fetched.emoji_id == "123"
    assert fetched.emoji_animated == true
    assert fetched.author_avatar_url == "https://cdn.discordapp.com/avatars/42/abc.png"
  end

  defp errors_on(changeset, field) do
    changeset.errors
    |> Keyword.get_values(field)
    |> Enum.map(fn {msg, _opts} -> msg end)
  end
end
