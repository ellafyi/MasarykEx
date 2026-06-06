defmodule MasarykEx.Services.Bookmarks do
  @moduledoc "Persistence for bookmarked messages."

  import Ecto.Query, only: [from: 2]

  alias MasarykEx.Repo
  alias MasarykEx.Services.Bookmarks.Bookmark

  @doc "Persist a bookmark from a plain attrs map."
  @spec create(map()) :: {:ok, Bookmark.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    %Bookmark{}
    |> Bookmark.changeset(attrs)
    |> Repo.insert()
  end

  @doc "A user's most recent bookmarks, newest first."
  @spec list_for_user(String.t(), keyword()) :: [Bookmark.t()]
  def list_for_user(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)

    Repo.all(
      from b in Bookmark,
        where: b.user_id == ^user_id,
        order_by: [desc: b.inserted_at],
        limit: ^limit
    )
  end
end
