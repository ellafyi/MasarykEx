defmodule MasarykEx.Interval do
  require Logger
  alias MasarykEx.Core.Router
  alias MasarykEx.Core.Event
  use GenServer

  @interval5m 5 * 60 * 1000
  @interval1h 60 * 60 * 1000
  @interval1d 24 * 60 * 60 * 1000

  def start_link(_), do: GenServer.start_link(__MODULE__, %{})

  def init(state) do
    Logger.info("Starting interval server")
    Process.send_after(self(), :interval5m, @interval5m)
    Process.send_after(self(), :interval1h, @interval1h)
    Process.send_after(self(), :interval1d, @interval1d)
    {:ok, state}
  end

  def handle_info(type, state) when type in [:interval5m, :interval1h, :interval1d] do
    interval =
      case type do
        :interval5m -> @interval5m
        :interval1h -> @interval1h
        :interval1d -> @interval1d
      end

    Logger.debug("Interval " <> to_string(type) <> " firing")

    Process.send_after(self(), type, interval)
    Router.dispatch(%Event{type: type})

    {:noreply, state}
  end
end
