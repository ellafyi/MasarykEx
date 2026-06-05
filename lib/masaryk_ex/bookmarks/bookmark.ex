defmodule MasarykEx.Bookmarks.Bookmark do
  @moduledoc "A message a user bookmarked via reaction."

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "bookmarks" do
    field :user_id, :string
    field :message_id, :string
    field :channel_id, :string
    field :guild_id, :string

    timestamps()
  end

  @doc false
  def changeset(bookmark, attrs) do
    bookmark
    |> cast(attrs, [:user_id, :message_id, :channel_id, :guild_id])
    |> validate_required([:user_id, :message_id])
  end
end
