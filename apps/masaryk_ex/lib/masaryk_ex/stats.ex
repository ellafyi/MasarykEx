defmodule MasarykEx.Stats do
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def increment(command), do: GenServer.cast(__MODULE__, {:increment, command})
  def get, do: GenServer.call(__MODULE__, :get)

  def init(_) do
    {:ok, %{started_at: DateTime.utc_now(), commands: %{}}}
  end

  def handle_cast({:increment, command}, state) do
    new_state = update_in(state, [:commands, command], &((&1 || 0) + 1))
    Phoenix.PubSub.broadcast(MasarykEx.PubSub, "stats", :updated)
    {:noreply, new_state}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end
end
