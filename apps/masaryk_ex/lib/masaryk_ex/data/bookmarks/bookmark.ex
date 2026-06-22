defmodule MasarykEx.Data.Bookmarks.Bookmark do
  @moduledoc "A message a user bookmarked."

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "bookmarks" do
    field :user_id, :string
    field :message_id, :string
    field :channel_id, :string
    field :guild_id, :string
    field :content, :string
    field :author, :string

    timestamps()
  end

  @doc false
  def changeset(bookmark, attrs) do
    bookmark
    |> cast(attrs, [:user_id, :message_id, :channel_id, :guild_id, :content, :author])
    |> validate_required([:user_id, :message_id])
  end
end
