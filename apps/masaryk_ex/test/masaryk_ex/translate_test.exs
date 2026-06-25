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
end
