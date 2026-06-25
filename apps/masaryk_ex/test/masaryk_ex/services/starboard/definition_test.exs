defmodule MasarykEx.Services.Starboard.DefinitionTest do
  use ExUnit.Case, async: false

  alias MasarykEx.Core.{Context, Event}
  alias MasarykEx.Data.Starboard.StarredMessages
  alias MasarykEx.Services.Starboard.Definition

  @config %{enabled: true, threshold: 2, channel_id: "555"}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MasarykEx.Repo)

    test_pid = self()

    on_exit(fn ->
      Application.delete_env(:masaryk_ex, :starboard_message_fetcher)
      Application.delete_env(:masaryk_ex, :starboard_message_poster)
      Application.delete_env(:masaryk_ex, :starboard_message_editor)
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

    %{test_pid: test_pid}
  end

  defp stub_message(count, opts \\ []) do
    emoji = Keyword.get(opts, :emoji, "⭐")

    message = %{
      content: Keyword.get(opts, :content, "hello world"),
      author: %{username: Keyword.get(opts, :author, "alice")},
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

  test "does nothing below the threshold" do
    stub_message(1)

    assert :ok = Definition.handle_event(event(:reaction_added), @config)

    refute_received {:posted, _, _}
    assert StarredMessages.get_by_message("200") == nil
  end

  test "posts once and stores the entry when the threshold is reached" do
    stub_message(2)

    assert :ok = Definition.handle_event(event(:reaction_added), @config)

    assert_received {:posted, 555, %{embeds: [embed]}}
    assert embed.description == "hello world"

    entry = StarredMessages.get_by_message("200")
    assert entry.reaction_count == 2
    assert entry.emoji == "⭐"
    assert entry.author == "alice"
    assert entry.starboard_message_id == "999"
  end

  test "edits the existing post instead of posting again when the count grows" do
    stub_message(2)
    Definition.handle_event(event(:reaction_added), @config)
    assert_received {:posted, _, _}

    stub_message(5)
    assert :ok = Definition.handle_event(event(:reaction_added), @config)

    refute_received {:posted, _, _}
    assert_received {:edited, 555, 999, _payload}
    assert StarredMessages.get_by_message("200").reaction_count == 5
  end

  test "a removal lowers the stored count and edits the post" do
    stub_message(3)
    Definition.handle_event(event(:reaction_added), @config)
    assert_received {:posted, _, _}

    stub_message(2)
    assert :ok = Definition.handle_event(event(:reaction_removed), @config)

    assert_received {:edited, 555, 999, _payload}
    assert StarredMessages.get_by_message("200").reaction_count == 2
  end

  test "ignores reactions in the starboard channel itself" do
    stub_message(10)

    assert :ok = Definition.handle_event(event(:reaction_added, %{channel_id: "555"}), @config)

    refute_received {:posted, _, _}
    assert StarredMessages.get_by_message("200") == nil
  end

  test "does nothing when no channel is configured" do
    stub_message(10)

    assert :ok = Definition.handle_event(event(:reaction_added), %{threshold: 2, channel_id: nil})

    refute_received {:posted, _, _}
  end

  test "inlines an image attachment in the embed and stores its url" do
    stub_message(2, attachments: [%{filename: "cat.png", url: "https://cdn/cat.png"}])

    assert :ok = Definition.handle_event(event(:reaction_added), @config)

    assert_received {:posted, 555, %{embeds: [embed]}}
    assert embed.image == %{url: "https://cdn/cat.png"}

    entry = StarredMessages.get_by_message("200")
    assert entry.media_url == "https://cdn/cat.png"
    assert entry.media_type == "image"
  end

  test "names a video attachment as the message text" do
    stub_message(2,
      attachments: [%{filename: "clip.mp4", url: "https://cdn/path/clip.mp4?ex=abc"}]
    )

    assert :ok = Definition.handle_event(event(:reaction_added), @config)

    assert_received {:posted, 555, payload}
    assert payload.content == "clip.mp4"
    refute Enum.any?(payload.embeds |> hd() |> Map.get(:fields), &(&1.name == "🎥 Video"))
    assert StarredMessages.get_by_message("200").media_type == "video"
  end

  test "falls back to an embed image such as a linked gif" do
    stub_message(2, embeds: [%{image: %{url: "https://tenor/x.gif"}}])

    assert :ok = Definition.handle_event(event(:reaction_added), @config)

    assert_received {:posted, 555, %{embeds: [embed]}}
    assert embed.image == %{url: "https://tenor/x.gif"}
    assert StarredMessages.get_by_message("200").media_url == "https://tenor/x.gif"
  end
end
