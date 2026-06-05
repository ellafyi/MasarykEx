defmodule MasarykEx.Bookmarks do
  @moduledoc "Persistence for bookmarked messages."

  alias MasarykEx.Repo
  alias MasarykEx.Bookmarks.Bookmark
  alias MasarykEx.Core.Context

  @doc "Persist a bookmark from a neutral reaction event's data + context."
  @spec create(map(), Context.t()) :: {:ok, Bookmark.t()} | {:error, Ecto.Changeset.t()}
  def create(data, %Context{} = context) do
    %Bookmark{}
    |> Bookmark.changeset(%{
      user_id: data.user_id,
      message_id: data.message_id,
      channel_id: Map.get(data, :channel_id),
      guild_id: context.guild_id
    })
    |> Repo.insert()
  end
end
