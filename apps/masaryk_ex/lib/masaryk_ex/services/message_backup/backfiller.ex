defmodule MasarykEx.Services.MessageBackup.Backfiller do
  @moduledoc """
  Supervised GenServer that drives the historical `Backfill` one batch at a time,
  pacing itself between batches. Pausing stops the walk only — live capture
  (`MessageBackup.Definition`) keeps running. The run flag is persisted via
  `Config.Store` so a restart resumes an in-progress backup. Progress is
  broadcast on the `"backup"` topic and announced in the configured log channel.
  """

  use GenServer

  alias MasarykEx.Adapters.Discord.Outbound
  alias MasarykEx.Config
  alias MasarykEx.Config.Store
  alias MasarykEx.Core.Context
  alias MasarykEx.Data.Backups.BackedUpMessages
  alias MasarykEx.Services.MessageBackup.{Backfill, Definition}

  @topic "backup"
  @feature "MessageBackup"
  @delay 250

  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @doc "Begin (or resume) the historical backfill."
  @spec start() :: :ok
  def start, do: GenServer.cast(__MODULE__, :start)

  @doc "Pause the historical backfill (live capture is unaffected)."
  @spec pause() :: :ok
  def pause, do: GenServer.cast(__MODULE__, :pause)

  @doc "Whether the backfill is currently running."
  @spec running?() :: boolean()
  def running?, do: GenServer.call(__MODULE__, :running?)

  @impl true
  def init(_) do
    running = persisted_running?()
    if running, do: send(self(), :resume)
    {:ok, %{running: running}}
  end

  @impl true
  def handle_cast(:start, state) do
    persist(true)
    Backfill.inventory()
    notify("📦 Message backup started.")
    schedule()
    broadcast()
    {:noreply, %{state | running: true}}
  end

  def handle_cast(:pause, state) do
    persist(false)
    broadcast()
    {:noreply, %{state | running: false}}
  end

  @impl true
  def handle_call(:running?, _from, state), do: {:reply, state.running, state}

  @impl true
  def handle_info(:resume, state) do
    Backfill.inventory()
    schedule()
    {:noreply, state}
  end

  def handle_info(:work, %{running: false} = state), do: {:noreply, state}

  def handle_info(:work, state) do
    case Backfill.step() do
      :done ->
        persist(false)
        notify("✅ Message backup complete (#{BackedUpMessages.total()} messages archived).")
        broadcast()
        {:noreply, %{state | running: false}}

      {:channel_done, channel} ->
        notify("✔️ Backed up ##{channel.name || channel.channel_id}.")
        broadcast()
        schedule()
        {:noreply, state}

      _progressed_or_error ->
        broadcast()
        schedule()
        {:noreply, state}
    end
  end

  defp schedule, do: Process.send_after(self(), :work, @delay)
  defp broadcast, do: Phoenix.PubSub.broadcast(MasarykEx.PubSub, @topic, {:backup, :progress})

  defp persist(running), do: Store.put(@feature, "running", "global", running)

  defp persisted_running? do
    match?({:ok, true}, Store.get(@feature, "running", "global"))
  end

  defp notify(text) do
    case log_channel() do
      nil -> :ok
      channel -> Outbound.create_message(channel, %{content: text})
    end
  end

  defp log_channel, do: Config.get(Definition, :channel_id, %Context{interface: :discord})
end
