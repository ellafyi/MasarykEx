defmodule MasarykEx.Data.Starboard.StarredMessages do
  @moduledoc "Persistence for messages posted to the starboard."

  import Ecto.Query, only: [from: 2]

  alias MasarykEx.Repo
  alias MasarykEx.Data.Starboard.StarredMessage

  @doc "Fetch the starred entry for a source message, or nil."
  @spec get_by_message(String.t()) :: StarredMessage.t() | nil
  def get_by_message(message_id) do
    Repo.get_by(StarredMessage, message_id: message_id)
  end

  @doc "Insert a new starred entry from a plain attrs map."
  @spec create(map()) :: {:ok, StarredMessage.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    %StarredMessage{}
    |> StarredMessage.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Update an existing starred entry."
  @spec update(StarredMessage.t(), map()) ::
          {:ok, StarredMessage.t()} | {:error, Ecto.Changeset.t()}
  def update(%StarredMessage{} = entry, attrs) do
    entry
    |> StarredMessage.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Starred entries newest first, paged with `:limit` and `:offset`. Pass
  `:starboard_id` to restrict to one board.
  """
  @spec list(keyword()) :: [StarredMessage.t()]
  def list(opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    Repo.all(
      from s in scope(opts),
        order_by: [desc: s.inserted_at, desc: s.id],
        limit: ^limit,
        offset: ^offset
    )
  end

  @doc "Total number of starred entries, optionally scoped by `:starboard_id`."
  @spec count(keyword()) :: non_neg_integer()
  def count(opts \\ []) do
    Repo.aggregate(scope(opts), :count, :id)
  end

  defp scope(opts) do
    case Keyword.get(opts, :starboard_id) do
      nil -> StarredMessage
      starboard_id -> from(s in StarredMessage, where: s.starboard_id == ^starboard_id)
    end
  end
end
