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
  alias MasarykEx.Data.Backups.{BackedUpMessages, BackupChannels}
  alias MasarykEx.Services.MessageBackup.{Backfill, Definition}

  require Logger

  @topic "backup"
  @feature "MessageBackup"
  @delay 250
  @broadcast_throttle 1_000
  @progress_notify_throttle 60_000

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
    {:ok, %{running: running, last_broadcast: 0, last_notify: 0}}
  end

  @impl true
  def handle_cast(:start, state) do
    persist(true)
    Backfill.inventory()
    notify("📦 Message backup started.")
    schedule()
    broadcast()
    {:noreply, %{state | running: true, last_broadcast: now(), last_notify: now()}}
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
    notify("▶️ Resuming message backup.")
    broadcast()
    schedule()
    {:noreply, %{state | last_broadcast: now(), last_notify: now()}}
  end

  def handle_info(:work, %{running: false} = state), do: {:noreply, state}

  def handle_info(:work, state) do
    case Backfill.step() do
      :done ->
        persist(false)

        notify(
          "✅ Message backup complete (~#{BackedUpMessages.estimated_total()} messages archived)."
        )

        broadcast()
        {:noreply, %{state | running: false, last_broadcast: now(), last_notify: now()}}

      {:channel_done, channel} ->
        notify("✔️ Backed up ##{channel.name || channel.channel_id}.")
        broadcast()
        schedule()
        {:noreply, %{state | last_broadcast: now(), last_notify: now()}}

      _progressed_or_error ->
        schedule()
        {:noreply, throttled_progress(state)}
    end
  end

  defp schedule, do: Process.send_after(self(), :work, @delay)
  defp broadcast, do: Phoenix.PubSub.broadcast(MasarykEx.PubSub, @topic, {:backup, :progress})

  defp throttled_progress(state) do
    now = now()
    state |> maybe_broadcast(now) |> maybe_notify_progress(now)
  end

  defp maybe_broadcast(state, now) do
    if now - state.last_broadcast >= @broadcast_throttle do
      broadcast()
      %{state | last_broadcast: now}
    else
      state
    end
  end

  defp maybe_notify_progress(state, now) do
    if now - state.last_notify >= @progress_notify_throttle do
      %{total: total, done: done} = BackupChannels.progress()

      notify(
        "📦 Backing up… #{done}/#{total} channels, ~#{BackedUpMessages.estimated_total()} messages archived."
      )

      %{state | last_notify: now}
    else
      state
    end
  end

  defp now, do: System.monotonic_time(:millisecond)

  defp persist(running), do: Store.put(@feature, "running", "global", running)

  defp persisted_running? do
    match?({:ok, true}, Store.get(@feature, "running", "global"))
  end

  defp notify(text) do
    case log_channel() do
      nil ->
        :ok

      channel ->
        case Outbound.create_message(channel, %{content: text}) do
          {:ok, _} -> :ok
          other -> Logger.warning("[Backfiller] log post to #{channel} failed: #{inspect(other)}")
        end
    end
  end

  defp log_channel do
    Config.get(Definition, :channel_id, %Context{interface: :discord, guild_id: guild_id()})
  end

  defp guild_id do
    case Application.get_env(:masaryk_ex, :discord_guild_id) do
      nil -> nil
      id -> to_string(id)
    end
  end
end
