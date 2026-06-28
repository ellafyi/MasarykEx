defmodule MasarykEx.Services.Starboard.DefinitionTest do
  use ExUnit.Case, async: false

  alias MasarykEx.Core.{Context, Event}
  alias MasarykEx.Data.Starboard.{Starboards, StarredMessages}
  alias MasarykEx.Services.Starboard.Definition

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MasarykEx.Repo)

    test_pid = self()

    on_exit(fn ->
      for key <- [
            :starboard_message_fetcher,
            :starboard_message_poster,
            :starboard_message_editor,
            :starboard_guild_emojis,
            :starboard_channel_fetcher
          ] do
        Application.delete_env(:masaryk_ex, key)
      end
    end)

    # Poster/editor record their calls so tests can assert what was sent.
    Application.put_env(:masaryk_ex, :starboard_message_poster, fn channel, payload ->
      send(test_pid, {:posted, channel, payload})
      {:ok, %{id: 999}}
    end)

    Application.put_env(:masaryk_ex, :starboard_message_editor, fn channel, message, payload ->
      send(test_pid, {:edited, channel, message, payload})
      {:ok, %{id: message}}
    end)

    # Default source channel is a normal text channel; thread/forum tests override.
    stub_channel(0)

    %{test_pid: test_pid}
  end

  defp create_board(overrides) do
    {:ok, board} =
      Starboards.create(
        Map.merge(
          %{
            guild_id: "9",
            name: "General",
            target_channel_id: "555",
            threshold: 2,
            thread_threshold: 2
          },
          overrides
        )
      )

    board
  end

  defp stub_channel(type, parent_id \\ nil) do
    Application.put_env(:masaryk_ex, :starboard_channel_fetcher, fn _id ->
      {:ok, %{type: type, parent_id: parent_id}}
    end)
  end

  defp stub_message(count, opts \\ []) do
    emoji = Keyword.get(opts, :emoji, "⭐")

    message = %{
      content: Keyword.get(opts, :content, "hello world"),
      author: %{
        username: Keyword.get(opts, :author, "alice"),
        id: Keyword.get(opts, :author_id),
        avatar: Keyword.get(opts, :author_avatar)
      },
      reactions: [%{emoji: %{name: emoji}, count: count}],
      attachments: Keyword.get(opts, :attachments, []),
      embeds: Keyword.get(opts, :embeds, [])
    }

    Application.put_env(:masaryk_ex, :starboard_message_fetcher, fn _channel, _message ->
      {:ok, message}
    end)
  end

  defp event(type, overrides \\ %{}) do
    data =
      Map.merge(
        %{emoji_name: "⭐", message_id: "200", user_id: "1", channel_id: "100"},
        overrides
      )

    %Event{
      type: type,
      data: data,
      context: %Context{interface: :discord, guild_id: "9", channel_id: data.channel_id}
    }
  end

  test "does nothing when no boards are configured" do
    stub_message(10)

    assert :ok = Definition.handle_event(event(:reaction_added), %{})

    refute_received {:posted, _, _}
    assert StarredMessages.get_by_message("200") == nil
  end

  test "a disabled board is excluded from routing even when its filter matches" do
    create_board(%{enabled: false, include_channel_ids: ["100"]})
    stub_message(10)

    assert :ok = Definition.handle_event(event(:reaction_added), %{})

    refute_received {:posted, _, _}
    assert StarredMessages.get_by_message("200") == nil
  end

  test "does nothing below the board's threshold" do
    create_board(%{threshold: 3})
    stub_message(2)

    assert :ok = Definition.handle_event(event(:reaction_added), %{})

    refute_received {:posted, _, _}
    assert StarredMessages.get_by_message("200") == nil
  end

  test "a normal-channel source uses the board threshold and routes to its target" do
    board = create_board(%{threshold: 2, thread_threshold: 5})
    stub_channel(0)
    stub_message(2)

    assert :ok = Definition.handle_event(event(:reaction_added), %{})

    assert_received {:posted, 555, %{embeds: [embed]}}
    assert embed.description == "hello world"

    entry = StarredMessages.get_by_message("200")
    assert entry.reaction_count == 2
    assert entry.starboard_id == board.id
  end

  test "a thread source routes by its parent channel and uses thread_threshold" do
    board =
      create_board(%{
        name: "Memes",
        target_channel_id: "777",
        include_channel_ids: ["100"],
        threshold: 10,
        thread_threshold: 2
      })

    # Source is a thread (type 11) whose parent is the included channel 100.
    stub_channel(11, "100")
    stub_message(2)

    assert :ok =
             Definition.handle_event(event(:reaction_added, %{channel_id: "999"}), %{})

    # Posted only because thread_threshold (2) was used, not threshold (10).
    assert_received {:posted, 777, _payload}
    assert StarredMessages.get_by_message("200").starboard_id == board.id
  end

  test "routes to the most-specific board when several are eligible" do
    _general = create_board(%{name: "General", target_channel_id: "555", position: 0})

    memes =
      create_board(%{
        name: "Memes",
        target_channel_id: "777",
        include_channel_ids: ["100"],
        position: 1
      })

    stub_channel(0)
    stub_message(3)

    assert :ok = Definition.handle_event(event(:reaction_added, %{channel_id: "100"}), %{})

    assert_received {:posted, 777, _payload}
    assert StarredMessages.get_by_message("200").starboard_id == memes.id
  end

  test "a reaction in a board's own target channel is a no-op" do
    create_board(%{target_channel_id: "555"})
    stub_message(10)

    assert :ok = Definition.handle_event(event(:reaction_added, %{channel_id: "555"}), %{})

    refute_received {:posted, _, _}
    assert StarredMessages.get_by_message("200") == nil
  end

  test "any emoji that reaches the threshold triggers (routing is channel-only)" do
    create_board(%{threshold: 2})
    stub_message(2, emoji: "🔥")

    assert :ok =
             Definition.handle_event(event(:reaction_added, %{emoji_name: "🔥"}), %{})

    assert_received {:posted, 555, _payload}
  end

  test "a channel-info :error falls back to normal-channel handling" do
    create_board(%{threshold: 2, thread_threshold: 99})
    Application.put_env(:masaryk_ex, :starboard_channel_fetcher, fn _id -> :error end)
    stub_message(2)

    assert :ok = Definition.handle_event(event(:reaction_added), %{})

    # Posted because the fallback used threshold (2), not thread_threshold (99).
    assert_received {:posted, 555, _payload}
  end

  test "edits the existing post instead of posting again when the count grows" do
    create_board(%{threshold: 2})
    stub_message(2)
    Definition.handle_event(event(:reaction_added), %{})
    assert_received {:posted, _, _}

    stub_message(5)
    assert :ok = Definition.handle_event(event(:reaction_added), %{})

    refute_received {:posted, _, _}
    assert_received {:edited, 555, 999, _payload}
    assert StarredMessages.get_by_message("200").reaction_count == 5
  end

  test "a removal lowers the stored count and edits the post" do
    create_board(%{threshold: 2})
    stub_message(3)
    Definition.handle_event(event(:reaction_added), %{})
    assert_received {:posted, _, _}

    stub_message(2)
    assert :ok = Definition.handle_event(event(:reaction_removed), %{})

    assert_received {:edited, 555, 999, _payload}
    assert StarredMessages.get_by_message("200").reaction_count == 2
  end

  test "inlines an image attachment in the embed and stores its url" do
    create_board(%{threshold: 2})
    stub_message(2, attachments: [%{filename: "cat.png", url: "https://cdn/cat.png"}])

    assert :ok = Definition.handle_event(event(:reaction_added), %{})

    assert_received {:posted, 555, %{embeds: [embed]}}
    assert embed.image == %{url: "https://cdn/cat.png"}

    entry = StarredMessages.get_by_message("200")
    assert entry.media_url == "https://cdn/cat.png"
    assert entry.media_type == "image"
  end

  test "names a video attachment as the message text" do
    create_board(%{threshold: 2})

    stub_message(2,
      attachments: [%{filename: "clip.mp4", url: "https://cdn/path/clip.mp4?ex=abc"}]
    )

    assert :ok = Definition.handle_event(event(:reaction_added), %{})

    assert_received {:posted, 555, payload}
    assert payload.content == "clip.mp4"
    assert StarredMessages.get_by_message("200").media_type == "video"
  end

  test "falls back to an embed image such as a linked gif" do
    create_board(%{threshold: 2})
    stub_message(2, embeds: [%{image: %{url: "https://tenor/x.gif"}}])

    assert :ok = Definition.handle_event(event(:reaction_added), %{})

    assert_received {:posted, 555, %{embeds: [embed]}}
    assert embed.image == %{url: "https://tenor/x.gif"}
    assert StarredMessages.get_by_message("200").media_url == "https://tenor/x.gif"
  end

  test "persists and renders avatar + custom emoji, and re-renders them on edit" do
    create_board(%{threshold: 2})

    Application.put_env(:masaryk_ex, :starboard_guild_emojis, fn _guild ->
      {:ok, [%{id: 123, name: "blob", animated: false}]}
    end)

    stub_message(2, emoji: "blob", author_id: 42, author_avatar: "abc")

    reaction =
      event(:reaction_added, %{emoji_name: "blob", emoji_id: "123", emoji_animated: false})

    assert :ok = Definition.handle_event(reaction, %{})

    assert_received {:posted, 555, %{embeds: [embed]}}

    assert embed.author == %{
             name: "alice",
             icon_url: "https://cdn.discordapp.com/avatars/42/abc.png"
           }

    assert reactions_field(embed) == "<:blob:123> 2"

    entry = StarredMessages.get_by_message("200")
    assert entry.emoji_id == "123"
    assert entry.author_avatar_url == "https://cdn.discordapp.com/avatars/42/abc.png"

    # The edit path re-renders the snapshot from the stored row.
    stub_message(5, emoji: "blob", author_id: 42, author_avatar: "abc")
    assert :ok = Definition.handle_event(reaction, %{})

    assert_received {:edited, 555, 999, %{embeds: [edited]}}
    assert reactions_field(edited) == "<:blob:123> 5"
  end

  defp reactions_field(embed) do
    Enum.find(embed.fields, &(&1.name == "Reactions")).value
  end
end
