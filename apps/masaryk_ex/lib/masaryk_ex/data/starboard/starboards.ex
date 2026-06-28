defmodule MasarykEx.Data.Starboard.Starboards do
  @moduledoc "Persistence and CRUD for user-defined starboards."

  import Ecto.Query, only: [from: 2]

  alias MasarykEx.Repo
  alias MasarykEx.Data.Starboard.Starboard

  @doc "Boards for a guild, ordered by `position` then `id`."
  @spec for_guild(String.t() | integer() | nil) :: [Starboard.t()]
  def for_guild(nil), do: []

  def for_guild(guild_id) do
    guild_id = to_string(guild_id)

    Repo.all(
      from b in Starboard,
        where: b.guild_id == ^guild_id,
        order_by: [asc: b.position, asc: b.id]
    )
  end

  @doc "Fetch a board by id, or nil."
  @spec get(integer() | String.t()) :: Starboard.t() | nil
  def get(id), do: Repo.get(Starboard, id)

  @doc "Insert a board from a plain attrs map."
  @spec create(map()) :: {:ok, Starboard.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    %Starboard{}
    |> Starboard.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Update a board."
  @spec update(Starboard.t(), map()) :: {:ok, Starboard.t()} | {:error, Ecto.Changeset.t()}
  def update(%Starboard{} = board, attrs) do
    board
    |> Starboard.changeset(attrs)
    |> Repo.update()
  end

  @doc "Delete a board."
  @spec delete(Starboard.t()) :: {:ok, Starboard.t()} | {:error, Ecto.Changeset.t()}
  def delete(%Starboard{} = board), do: Repo.delete(board)
end
