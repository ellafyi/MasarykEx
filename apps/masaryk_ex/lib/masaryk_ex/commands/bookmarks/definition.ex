defmodule MasarykEx.Commands.Bookmarks.Definition do
  @moduledoc "List your bookmarked messages."

  use MasarykEx.Core.Command

  alias MasarykEx.Core.{Embed, Request, Response}
  alias MasarykEx.Data.Bookmarks

  @impl true
  def definition do
    %{name: "bookmarks", description: "List your bookmarked messages", args: []}
  end

  @impl true
  def run(%Request{context: %{user_id: nil}}) do
    Response.text("I couldn't tell who you are.", ephemeral: true)
  end

  def run(%Request{context: context}) do
    case Bookmarks.list_for_user(context.user_id) do
      [] ->
        Response.text(
          "You have no bookmarks yet. Right-click a message → Apps → Bookmark.",
          ephemeral: true
        )

      bookmarks ->
        %Response{
          ephemeral: true,
          embed: %Embed{
            title: "Your bookmarks (#{length(bookmarks)})",
            color: 0xFEE75C,
            fields: Enum.map(bookmarks, &field/1)
          }
        }
    end
  end

  defp field(bookmark) do
    %{
      name: snippet(bookmark.content),
      value:
        "<##{bookmark.channel_id}> · [jump](#{jump(bookmark)}) · #{date(bookmark.inserted_at)}"
    }
  end

  defp snippet(nil), do: "(no text)"

  defp snippet(content) do
    text = content |> String.replace(~r/\s+/u, " ") |> String.trim()

    cond do
      text == "" -> "(no text)"
      String.length(text) > 80 -> String.slice(text, 0, 80) <> "…"
      true -> text
    end
  end

  defp jump(b), do: "https://discord.com/channels/#{b.guild_id}/#{b.channel_id}/#{b.message_id}"

  defp date(datetime), do: Calendar.strftime(datetime, "%Y-%m-%d")
end
