defmodule MasarykEx.Commands.Bookmark do
  @moduledoc "Save a message to your bookmarks (right-click → Apps → Bookmark)."

  use MasarykEx.Core.Command

  alias MasarykEx.Core.{Request, Response}
  alias MasarykEx.Services.Bookmarks

  @impl true
  def definition do
    %{name: "Bookmark", type: :message}
  end

  @impl true
  def run(%Request{args: %{"message" => message}, context: context}) do
    attrs = %{
      user_id: context.user_id,
      message_id: message["id"],
      channel_id: message["channel_id"],
      guild_id: context.guild_id,
      content: message["content"],
      author: message["author"]
    }

    case Bookmarks.create(attrs) do
      {:ok, _} -> Response.text("✔ Saved to your bookmarks", ephemeral: true)
      {:error, _} -> Response.text("Couldn't save that bookmark.", ephemeral: true)
    end
  end

  def run(_request) do
    Response.text("Use this by right-clicking a message → Apps → Bookmark.", ephemeral: true)
  end
end
