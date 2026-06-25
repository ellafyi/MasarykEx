defmodule MasarykEx.Application do
  @moduledoc false

  use Application

  alias MasarykEx.Autoloader

  require Logger

  @impl true
  def start(_type, _args) do
    maybe_start_nostrum()

    children =
      [
        {Phoenix.PubSub, name: MasarykEx.PubSub},
        MasarykEx.Repo,
        MasarykEx.Config.Store,
        MasarykEx.Stats
      ] ++
        service_children() ++ discord_children()

    Supervisor.start_link(children, strategy: :one_for_one, name: MasarykEx.Supervisor)
  end

  # Services exporting child_spec/1 are supervised; passive ones are invoked by
  # the Router at runtime instead.
  defp service_children do
    Autoloader.modules_with_function(MasarykEx.Services, :child_spec, 1)
    |> Enum.map(fn module ->
      Logger.info("Starting active service: #{inspect(module)}")
      module.child_spec([])
    end)
  end

  defp discord_children do
    if discord_enabled?() do
      [MasarykEx.Adapters.Discord.Consumer]
    else
      Logger.info("Discord adapter disabled (no BOT_TOKEN or DISCORD_ENABLED=false)")
      []
    end
  end

  defp maybe_start_nostrum do
    if discord_enabled?(), do: {:ok, _} = Application.ensure_all_started(:nostrum)
  end

  defp discord_enabled?, do: Application.get_env(:masaryk_ex, :discord_enabled, true)
end
