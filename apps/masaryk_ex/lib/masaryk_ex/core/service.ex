defmodule MasarykEx.Core.Service do
  @moduledoc """
  Interface-neutral behaviour for background features that react to events.
  Services get a neutral `%Event{}` plus their resolved config map. Drop a file
  in `lib/masaryk_ex/services/` and restart, the `Autoloader` attaches it.

  Implement `handle_event/2` for a passive service (the `Router` calls it in a
  fire-and-forget Task). Also define `child_spec/1` (or `use GenServer`) for a
  stateful one, the supervisor auto-starts any service exporting `child_spec/1`.
  Optionally implement `config_schema/0` to declare settings + defaults.
  """

  alias MasarykEx.Core.Event

  @callback handle_event(Event.t(), config :: map()) :: :ok
  @callback child_spec(init_arg :: term()) :: Supervisor.child_spec()
  @callback config_schema() :: map()

  @optional_callbacks child_spec: 1, config_schema: 0

  defmacro __using__(_opts) do
    quote do
      @behaviour MasarykEx.Core.Service
    end
  end
end
