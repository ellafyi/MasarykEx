defmodule MasarykEx.Data.Backups.BackedUpMessage do
  @moduledoc "An archived Discord message. Deletions are soft (`deleted_at`)."

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "backed_up_messages" do
    field :message_id, :string
    field :channel_id, :string
    field :author_id, :string
    field :author_username, :string
    field :content, :string
    field :posted_at, :utc_datetime
    field :edited_at, :utc_datetime
    field :deleted_at, :utc_datetime
    field :type, :integer
    field :pinned, :boolean, default: false
    field :reply_to_message_id, :string
    field :attachment_urls, {:array, :string}, default: []

    timestamps()
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :message_id,
      :channel_id,
      :author_id,
      :author_username,
      :content,
      :posted_at,
      :edited_at,
      :deleted_at,
      :type,
      :pinned,
      :reply_to_message_id,
      :attachment_urls
    ])
    |> validate_required([:message_id])
    |> unique_constraint(:message_id)
  end
end
