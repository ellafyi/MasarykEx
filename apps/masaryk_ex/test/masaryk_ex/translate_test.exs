defmodule MasarykEx.Adapters.Discord.TranslateTest do
  use ExUnit.Case, async: true

  alias MasarykEx.Adapters.Discord.Translate
  alias MasarykEx.Core.{Embed, Response}

  test "renders a plain text response" do
    assert %{type: 4, data: %{content: "hi", flags: 64}} =
             Translate.to_discord_response(Response.text("hi", ephemeral: true))
  end

  test "renders an embed response (nil fields dropped, no crash)" do
    response = %Response{
      ephemeral: true,
      embed: %Embed{
        title: "Your bookmarks (1)",
        fields: [%{name: "n", value: "v", inline: false}]
      }
    }

    assert %{type: 4, data: data} = Translate.to_discord_response(response)
    assert [embed] = data.embeds
    assert embed.title == "Your bookmarks (1)"
    assert embed.fields == [%{name: "n", value: "v", inline: false}]
    refute Map.has_key?(embed, :description)
    refute Map.has_key?(embed, :footer)
    assert data.flags == 64
  end

  test "captures custom-emoji id and animated flag on a reaction add" do
    reaction = %{
      emoji: %{name: "blob", id: 123, animated: true},
      message_id: 200,
      user_id: 1,
      channel_id: 100,
      guild_id: 9
    }

    event = Translate.to_event(:MESSAGE_REACTION_ADD, reaction)
    assert event.type == :reaction_added
    assert event.data.emoji_name == "blob"
    assert event.data.emoji_id == "123"
    assert event.data.emoji_animated == true
  end

  test "captures a unicode reaction removal with no emoji id" do
    reaction = %{
      emoji: %{name: "⭐", id: nil, animated: nil},
      message_id: 200,
      user_id: 1,
      channel_id: 100,
      guild_id: 9
    }

    event = Translate.to_event(:MESSAGE_REACTION_REMOVE, reaction)
    assert event.type == :reaction_removed
    assert event.data.emoji_name == "⭐"
    assert event.data.emoji_id == nil
    assert event.data.emoji_animated == false
  end
end
