defmodule MasarykEx.Data.Starboard.Starboard do
  @moduledoc """
  A user-defined starboard: a target channel plus the channel filters and
  reaction thresholds that decide which reacted messages get reposted to it.

  `include_channel_ids` is an allowlist (empty = every channel); a membership
  channel listed in `exclude_channel_ids` is never routed here. `threshold`
  applies to normal channels, `thread_threshold` to thread/forum sources.
  `position` orders boards and breaks routing ties.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "starboards" do
    field :guild_id, :string
    field :name, :string
    field :target_channel_id, :string
    field :include_channel_ids, {:array, :string}, default: []
    field :exclude_channel_ids, {:array, :string}, default: []
    field :threshold, :integer, default: 3
    field :thread_threshold, :integer, default: 3
    field :position, :integer, default: 0
    field :enabled, :boolean, default: true

    timestamps()
  end

  @doc false
  def changeset(starboard, attrs) do
    starboard
    |> cast(attrs, [
      :guild_id,
      :name,
      :target_channel_id,
      :include_channel_ids,
      :exclude_channel_ids,
      :threshold,
      :thread_threshold,
      :position,
      :enabled
    ])
    |> update_change(:include_channel_ids, &normalize_ids/1)
    |> update_change(:exclude_channel_ids, &normalize_ids/1)
    |> validate_required([:guild_id, :name, :target_channel_id])
    |> validate_number(:threshold, greater_than: 0)
    |> validate_number(:thread_threshold, greater_than: 0)
    |> unique_constraint([:guild_id, :name], name: :starboards_guild_id_name_index)
  end

  @doc """
  Normalize a raw id list: trim each entry, drop anything that isn't a pure
  digit-string (blanks, channel mentions, junk), and dedupe while preserving
  order.
  """
  @spec normalize_ids([term()]) :: [String.t()]
  def normalize_ids(ids) when is_list(ids) do
    ids
    |> Enum.map(&(&1 |> to_string() |> String.trim()))
    |> Enum.filter(&digits?/1)
    |> Enum.uniq()
  end

  def normalize_ids(_), do: []

  defp digits?(""), do: false
  defp digits?(value), do: String.match?(value, ~r/\A\d+\z/)
end
