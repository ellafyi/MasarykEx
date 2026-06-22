defmodule MasarykEx.Core.Command do
  @moduledoc """
  Interface-neutral behaviour for a command. Create a folder
  `lib/masaryk_ex/commands/<feature>/` with a `definition.ex` that implements
  this behaviour (module `MasarykEx.Commands.<Feature>.Definition`); the
  `Autoloader` exposes it through every adapter. Put supporting code in sibling
  files in the same folder. A command receives a `%Request{}` and returns a
  `%Response{}` — it knows nothing about Discord.

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
  Converts a kebab-case command name to its definition module.
  "restaurant-menus" -> MasarykEx.Commands.RestaurantMenus.Definition
  """
  @spec to_module(String.t()) :: module()
  def to_module(name) when is_binary(name) do
    module_name = name |> String.split("-") |> Enum.map_join(&String.capitalize/1)
    Module.concat([MasarykEx.Commands, module_name, "Definition"])
  end
end
