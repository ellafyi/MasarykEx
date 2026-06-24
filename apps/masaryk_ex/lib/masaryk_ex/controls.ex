defmodule MasarykEx.Controls do
  @moduledoc """
  Admin-facing view over command enable/disable state, backing the web control
  panel.

  Reads resolve through `MasarykEx.Config` (ETS cache + defaults, no DB); writes
  go through `MasarykEx.Config.Store` at the global scope — the same mechanism
  the `/config` command uses — so `Core.Dispatcher` picks up changes on the next
  invocation, with no restart.
  """

  alias MasarykEx.{Autoloader, Config}
  alias MasarykEx.Config.Store
  alias MasarykEx.Core.Context

  @topic "controls"
  @web_context %Context{interface: :web}

  @type command :: %{
          module: module(),
          name: String.t(),
          description: String.t(),
          enabled: boolean()
        }

  @doc "All commands with their current global `enabled` state, sorted by name."
  @spec list_commands() :: [command()]
  def list_commands do
    Autoloader.modules_with_function(MasarykEx.Commands, :definition, 0)
    |> Enum.map(fn module ->
      definition = module.definition()

      %{
        module: module,
        name: definition.name,
        description: Map.get(definition, :description, ""),
        enabled: Config.get(module, :enabled, @web_context) == true
      }
    end)
    |> Enum.sort_by(& &1.name)
  end

  @doc "Set a command's global `enabled` override and broadcast the change."
  @spec set_enabled(module(), boolean()) :: :ok | {:error, term()}
  def set_enabled(module, enabled?) when is_atom(module) and is_boolean(enabled?) do
    case Store.put(inspect(module), "enabled", "global", enabled?) do
      :ok ->
        Phoenix.PubSub.broadcast(MasarykEx.PubSub, @topic, {:command_toggled, module, enabled?})
        :ok

      error ->
        error
    end
  end

  @doc "PubSub topic LiveViews subscribe to for live toggle updates."
  @spec topic() :: String.t()
  def topic, do: @topic
end
