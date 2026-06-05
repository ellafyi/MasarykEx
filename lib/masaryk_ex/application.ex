defmodule MasarykEx.Application do
  @moduledoc false

  use Application

  alias MasarykEx.Autoloader

  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      # Discord gateway consumer (handles READY, INTERACTION_CREATE, etc.)
      MasarykEx.Consumer
      | service_children()
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: MasarykEx.Supervisor)
  end

  # Services that export `child_spec/1` are started as supervised processes.
  # Pure event-handler services (no child_spec) are NOT started here;
  # the Consumer routes events to them at runtime instead.
  defp service_children do
    Autoloader.modules_with_function(MasarykEx.Services, :child_spec, 1)
    |> Enum.map(fn module ->
      Logger.info("Starting active service: #{module}")
      module.child_spec([])
    end)
  end
end
