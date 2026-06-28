defmodule MasarykEx.Starboard do
  @moduledoc """
  Dashboard-facing facade over the starboard: CRUD for the per-guild boards and
  a paged view of persisted starred messages.

  Boards live in the `starboards` table scoped to the configured guild
  (`:discord_guild_id`). The running service reloads them on the next event with
  no restart, and every mutation broadcasts `{:starboard, :config}` so open
  dashboards refresh live. Board attrs are atom-keyed maps; `guild_id` is
  injected from the app env on create.
  """

  alias MasarykEx.Data.Starboard.{Starboard, Starboards, StarredMessage, StarredMessages}

  @topic "starboard"

  @doc "All boards for the configured guild, ordered by position then id."
  @spec list_starboards() :: [Starboard.t()]
  def list_starboards, do: Starboards.for_guild(guild_id())

  @doc "Fetch a board by id, or nil."
  @spec get_starboard(integer() | String.t()) :: Starboard.t() | nil
  def get_starboard(id), do: Starboards.get(id)

  @doc "Create a board for the configured guild and broadcast the change."
  @spec create_starboard(map()) :: {:ok, Starboard.t()} | {:error, Ecto.Changeset.t()}
  def create_starboard(attrs) do
    attrs
    |> Map.put(:guild_id, guild_id())
    |> Starboards.create()
    |> broadcast_config()
  end

  @doc "Update a board and broadcast the change."
  @spec update_starboard(Starboard.t(), map()) ::
          {:ok, Starboard.t()} | {:error, Ecto.Changeset.t()}
  def update_starboard(%Starboard{} = board, attrs) do
    board
    |> Starboards.update(attrs)
    |> broadcast_config()
  end

  @doc "Delete a board and broadcast the change."
  @spec delete_starboard(Starboard.t()) :: {:ok, Starboard.t()} | {:error, Ecto.Changeset.t()}
  def delete_starboard(%Starboard{} = board) do
    board
    |> Starboards.delete()
    |> broadcast_config()
  end

  @doc "A page of starred messages, newest first; optional `:starboard_id` filter."
  @spec list(keyword()) :: [StarredMessage.t()]
  def list(opts \\ []), do: StarredMessages.list(opts)

  @doc "Number of starred messages, optionally scoped by `:starboard_id`."
  @spec count(keyword()) :: non_neg_integer()
  def count(opts \\ []), do: StarredMessages.count(opts)

  @doc "PubSub topic LiveViews subscribe to for live starboard updates."
  @spec topic() :: String.t()
  def topic, do: @topic

  @doc "The configured Discord guild id as a string, or nil when unset."
  @spec guild_id() :: String.t() | nil
  def guild_id do
    case Application.get_env(:masaryk_ex, :discord_guild_id) do
      nil -> nil
      id -> to_string(id)
    end
  end

  defp broadcast_config({:ok, _} = result) do
    Phoenix.PubSub.broadcast(MasarykEx.PubSub, @topic, {:starboard, :config})
    result
  end

  defp broadcast_config(other), do: other
end
