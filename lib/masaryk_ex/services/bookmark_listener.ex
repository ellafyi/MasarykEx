defmodule MasarykEx.Services.BookmarkListener do
  @moduledoc """
  Example active service that runs as its own supervised GenServer.
  It tracks bookmark reactions and could DM users or store data.

  Because this module exports `child_spec/1` (via `use GenServer`),
  the Application supervisor will automatically start it at boot.
  """

  use GenServer
  @behaviour MasarykEx.Service

  require Logger

  # --- GenServer client ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # --- Service event hook (called by the Consumer) ---

  @impl MasarykEx.Service
  def handle_event(:MESSAGE_REACTION_ADD, %{emoji: %{name: "🔖"}} = reaction, _ws) do
    GenServer.cast(__MODULE__, {:bookmark, reaction.message_id, reaction.user_id})
    :ok
  end

  def handle_event(_type, _payload, _ws), do: :ok

  # --- GenServer server ---

  @impl GenServer
  def init(_opts) do
    Logger.info("BookmarkListener started")
    {:ok, %{bookmarked: MapSet.new()}}
  end

  @impl GenServer
  def handle_cast({:bookmark, _msg_id, user_id}, state) do
    # TODO: DM the user, store in DB, etc.
    Logger.info("BookmarkListener: user #{user_id} bookmarked a message")
    {:noreply, state}
  end
end
