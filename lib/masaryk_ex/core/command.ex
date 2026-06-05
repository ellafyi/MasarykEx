defmodule MasarykEx.Core.Command do
  @moduledoc """
  Interface-neutral behaviour for a command. Drop a file in
  `lib/masaryk_ex/commands/`, implement this, and the `Autoloader` exposes it
  through every adapter. A command receives a `%Request{}` and returns a
  `%Response{}`,it knows nothing about Discord.

  `definition/0` returns a neutral spec `%{name, description, args}` where each
  arg is `%{name, type, required, description}`; adapters translate `args` into
  their own input model (Discord options, CLI flags). Optionally implement
  `config_schema/0` to declare settings + defaults (see `MasarykEx.Config`).
  """

  alias MasarykEx.Core.{Request, Response}

  @callback definition() :: map()
  @callback run(Request.t()) :: Response.t()
  @callback config_schema() :: map()

  @optional_callbacks config_schema: 0

  defmacro __using__(_opts) do
    quote do
      @behaviour MasarykEx.Core.Command
    end
  end

  @doc """
  Converts a kebab-case command name to its Elixir module.
  "restaurant-menus" -> MasarykEx.Commands.RestaurantMenus
  """
  @spec to_module(String.t()) :: module()
  def to_module(name) when is_binary(name) do
    segments =
      name
      |> String.split("-")
      |> Enum.map(&String.capitalize/1)

    Module.concat([MasarykEx.Commands | segments])
  end
end
