defmodule MasarykEx.Data.Starboard.StarredMessage do
  @moduledoc "A message that reached the starboard reaction threshold."

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "starred_messages" do
    field :message_id, :string
    field :channel_id, :string
    field :guild_id, :string
    field :author, :string
    field :content, :string
    field :emoji, :string
    field :reaction_count, :integer, default: 0
    field :starboard_message_id, :string

    timestamps()
  end

  @doc false
  def changeset(starred_message, attrs) do
    starred_message
    |> cast(attrs, [
      :message_id,
      :channel_id,
      :guild_id,
      :author,
      :content,
      :emoji,
      :reaction_count,
      :starboard_message_id
    ])
    |> validate_required([:message_id, :emoji])
    |> unique_constraint(:message_id)
  end
end
