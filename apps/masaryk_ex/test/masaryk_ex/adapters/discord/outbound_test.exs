defmodule MasarykEx.Adapters.Discord.OutboundTest do
  use ExUnit.Case, async: false

  alias MasarykEx.Adapters.Discord.Outbound

  @base %{
    author: "alice",
    content: "hello world",
    guild_id: "9",
    channel_id: "100",
    message_id: "200",
    emoji: "⭐",
    reaction_count: 3
  }

  setup do
    on_exit(fn -> Application.delete_env(:masaryk_ex, :starboard_guild_emojis) end)
    :ok
  end

  defp embed(attrs) do
    %{embeds: [embed]} = Outbound.starboard_embed(Map.merge(@base, attrs))
    embed
  end

  defp stub_emojis(result) do
    Application.put_env(:masaryk_ex, :starboard_guild_emojis, fn _guild -> result end)
  end

  describe "starboard_embed/1 source field" do
    test "includes the channel mention next to the jump link" do
      field = Enum.find(embed(%{}).fields, &(&1.name == "Source"))
      assert field.name == "Source"

      assert field.value ==
               "<#100> · [Jump to message](https://discord.com/channels/9/100/200)"
    end
  end

  describe "starboard_embed/1 reactions field" do
    test "renders a unicode reaction in a field value, with no footer" do
      e = embed(%{emoji: "⭐", emoji_id: nil, reaction_count: 4})
      field = Enum.find(e.fields, &(&1.name == "Reactions"))

      assert field.value == "⭐ 4"
      # Custom emoji render only in description/field values, never the footer.
      refute Map.has_key?(e, :footer)
    end

    test "renders a this-guild custom emoji as <:name:id> in the field value" do
      stub_emojis({:ok, [%{id: 123, name: "blob", animated: false}]})

      e = embed(%{emoji: "blob", emoji_id: "123", emoji_animated: false, reaction_count: 7})
      field = Enum.find(e.fields, &(&1.name == "Reactions"))

      assert field.value == "<:blob:123> 7"
      refute Map.has_key?(e, :footer)
    end
  end

  describe "starboard_embed/1 author" do
    test "adds icon_url when author_avatar_url is set" do
      author = embed(%{author_avatar_url: "https://cdn/avatar.png"}).author
      assert author == %{name: "alice", icon_url: "https://cdn/avatar.png"}
    end

    test "omits the icon_url key when there is no avatar url" do
      author = embed(%{}).author
      assert author == %{name: "alice"}
      refute Map.has_key?(author, :icon_url)
    end

    test "drops the author block entirely when there is no author" do
      refute Map.has_key?(embed(%{author: nil}), :author)
    end
  end

  describe "render_emoji/1" do
    test "passes a unicode emoji through unchanged" do
      assert Outbound.render_emoji(%{emoji: "⭐", emoji_id: nil, guild_id: "9"}) == "⭐"
    end

    test "renders a this-guild custom emoji as <:name:id>" do
      stub_emojis({:ok, [%{id: 123, name: "blob", animated: false}]})

      assert Outbound.render_emoji(%{
               emoji: "blob",
               emoji_id: "123",
               emoji_animated: false,
               guild_id: "9"
             }) == "<:blob:123>"
    end

    test "renders an animated this-guild custom emoji as <a:name:id>" do
      stub_emojis({:ok, [%{id: 123, name: "blob", animated: true}]})

      assert Outbound.render_emoji(%{
               emoji: "blob",
               emoji_id: "123",
               emoji_animated: true,
               guild_id: "9"
             }) == "<a:blob:123>"
    end

    test "falls back to text for a custom emoji from another guild" do
      stub_emojis({:ok, [%{id: 999, name: "other", animated: false}]})

      assert Outbound.render_emoji(%{
               emoji: "blob",
               emoji_id: "123",
               emoji_animated: false,
               guild_id: "9"
             }) == ":blob:"
    end

    test "falls back to text when the guild-emoji fetch errors" do
      stub_emojis(:error)

      assert Outbound.render_emoji(%{
               emoji: "blob",
               emoji_id: "123",
               emoji_animated: false,
               guild_id: "9"
             }) == ":blob:"
    end
  end

  describe "author_avatar_url/1" do
    test "builds a png url for a static avatar" do
      assert Outbound.author_avatar_url(%{author: %{id: 42, avatar: "abc"}}) ==
               "https://cdn.discordapp.com/avatars/42/abc.png"
    end

    test "builds a gif url for an animated avatar" do
      assert Outbound.author_avatar_url(%{author: %{id: 42, avatar: "a_xyz"}}) ==
               "https://cdn.discordapp.com/avatars/42/a_xyz.gif"
    end

    test "returns nil when the author has no avatar hash" do
      assert Outbound.author_avatar_url(%{author: %{id: 42, avatar: nil}}) == nil
      assert Outbound.author_avatar_url(%{author: %{username: "alice"}}) == nil
    end
  end
end
