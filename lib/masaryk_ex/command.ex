defmodule MasarykEx.Command do
  @moduledoc """
  Behaviour for Discord slash commands.

  Drop a new file in `lib/masaryk_ex/commands/`, implement this behaviour,
  and it will be registered and dispatched automatically.
  """

  @callback definition() :: map()
  @callback handle(Nostrum.Struct.Interaction.t()) :: map()

  defmacro __using__(_opts) do
    quote do
      @behaviour MasarykEx.Command
    end
  end

  @doc """
  Converts a Discord kebab-case command name to its Elixir module.
  "restaurant-menus" -> MasarykEx.Commands.RestaurantMenus
  """
  def to_module(name) when is_binary(name) do
    segments =
      name
      |> String.split("-")
      |> Enum.map(&String.capitalize/1)

    Module.concat([MasarykEx.Commands | segments])
  end
end
