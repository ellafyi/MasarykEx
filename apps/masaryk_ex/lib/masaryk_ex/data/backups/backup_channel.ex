defmodule MasarykEx.Data.Backups.BackupChannel do
  @moduledoc "Backfill progress for one Discord channel (resumable cursor)."

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "backup_channels" do
    field :channel_id, :string
    field :name, :string
    field :after_cursor, :string, default: "0"
    field :done, :boolean, default: false
    field :message_count, :integer, default: 0
    field :last_run_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:channel_id, :name, :after_cursor, :done, :message_count, :last_run_at])
    |> validate_required([:channel_id])
    |> unique_constraint(:channel_id)
  end
end
