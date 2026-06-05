defmodule MasarykEx.Services.BookmarkListener do
  @moduledoc """
  Active service that persists a bookmark whenever a 🔖 reaction is added.
  Supervised as a GenServer (exports child_spec/1 via `use GenServer`).
  """

  use GenServer
  use MasarykEx.Core.Service

  alias MasarykEx.Bookmarks
  alias MasarykEx.Core.Event

  require Logger

  @emoji "🔖"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl MasarykEx.Core.Service
  def handle_event(%Event{type: :reaction_added, data: %{emoji_name: @emoji} = data} = event, _config) do
    GenServer.cast(__MODULE__, {:bookmark, data, event.context})
    :ok
  end

  def handle_event(_event, _config), do: :ok

  @impl GenServer
  def init(_opts) do
    Logger.info("BookmarkListener started")
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:bookmark, data, context}, state) do
    case Bookmarks.create(data, context) do
      {:ok, _bookmark} ->
        Logger.info("Bookmarked message #{data.message_id} for user #{data.user_id}")

      {:error, changeset} ->
        Logger.error("Bookmark failed: #{inspect(changeset.errors)}")
    end

    {:noreply, state}
  end
end
