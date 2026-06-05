defmodule MasarykEx.Service do
  @moduledoc """
  Behaviour for background services that react to Discord events.

  ## Passive services
  Implement `handle_event/3` to receive events without running your own process.
  The consumer will call your module directly in a fire-and-forget Task.

  ## Active / Stateful services
  If you need a supervised process (e.g. to cache state, run timers, etc.),
  also define `child_spec/1` or `use GenServer`. The Application supervisor
  will auto-start any service module that exports `child_spec/1`.

  ## Discovery
  Drop a new file in `lib/masaryk_ex/services/` and restart the bot.
  It will attach automatically.
  """

  @callback handle_event(type :: atom, payload :: term, ws_state :: map) :: :ok
  @callback child_spec(init_arg :: term) :: Supervisor.child_spec()

  @optional_callbacks child_spec: 1
end
