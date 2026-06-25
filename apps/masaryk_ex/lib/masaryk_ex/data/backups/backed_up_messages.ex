defmodule MasarykEx.Data.Backups.BackedUpMessages do
  @moduledoc """
  Persistence and full-text search for archived messages. Writes dedupe on
  `message_id`; search runs against the generated `search_vector` column.
  """

  import Ecto.Query

  alias MasarykEx.Repo
  alias MasarykEx.Data.Backups.BackedUpMessage

  @doc "Archive a message, ignoring it if already stored."
  @spec upsert(map()) :: {:ok, BackedUpMessage.t() | nil} | {:error, Ecto.Changeset.t()}
  def upsert(attrs) do
    %BackedUpMessage{}
    |> BackedUpMessage.changeset(attrs)
    |> Repo.insert(on_conflict: :nothing, conflict_target: :message_id)
  end

  @doc "Fetch an archived message by its Discord id, or nil."
  @spec get_by_message(String.t()) :: BackedUpMessage.t() | nil
  def get_by_message(message_id), do: Repo.get_by(BackedUpMessage, message_id: message_id)

  @doc "Update a stored message's content/edit time. No-op if it isn't archived."
  @spec mark_edited(String.t(), map()) :: {non_neg_integer(), nil}
  def mark_edited(message_id, attrs) do
    from(m in BackedUpMessage, where: m.message_id == ^message_id)
    |> Repo.update_all(
      set: [content: attrs[:content], edited_at: attrs[:edited_at] || now(), updated_at: now()]
    )
  end

  @doc "Soft-delete a stored message. No-op if it isn't archived or already deleted."
  @spec mark_deleted(String.t()) :: {non_neg_integer(), nil}
  def mark_deleted(message_id) do
    from(m in BackedUpMessage, where: m.message_id == ^message_id and is_nil(m.deleted_at))
    |> Repo.update_all(set: [deleted_at: now(), updated_at: now()])
  end

  @doc """
  Search archived messages, newest first. Options: `:query` (full-text),
  `:author_id`, `:channel_id`, `:limit`, `:offset`.
  """
  @spec search(keyword()) :: [BackedUpMessage.t()]
  def search(opts \\ []) do
    opts
    |> base_query()
    |> order_by([m], desc: m.posted_at, desc: m.id)
    |> limit(^Keyword.get(opts, :limit, 25))
    |> offset(^Keyword.get(opts, :offset, 0))
    |> Repo.all()
  end

  @doc "Number of archived messages matching the same options as `search/1`."
  @spec count(keyword()) :: non_neg_integer()
  def count(opts \\ []) do
    opts |> base_query() |> Repo.aggregate(:count, :id)
  end

  @doc "Total number of archived messages."
  @spec total() :: non_neg_integer()
  def total, do: Repo.aggregate(BackedUpMessage, :count, :id)

  defp base_query(opts) do
    BackedUpMessage
    |> filter_text(opts[:query])
    |> filter_eq(:author_id, opts[:author_id])
    |> filter_eq(:channel_id, opts[:channel_id])
  end

  defp filter_text(query, text) when text in [nil, ""], do: query

  defp filter_text(query, text) do
    where(query, [m], fragment("search_vector @@ websearch_to_tsquery('simple', ?)", ^text))
  end

  defp filter_eq(query, _field, value) when value in [nil, ""], do: query
  defp filter_eq(query, :author_id, value), do: where(query, [m], m.author_id == ^value)
  defp filter_eq(query, :channel_id, value), do: where(query, [m], m.channel_id == ^value)

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
