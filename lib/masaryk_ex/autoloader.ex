defmodule MasarykEx.Autoloader do
  @moduledoc """
  Runtime module discovery. Scans the application's compiled modules
  to find everything under a given namespace.
  """

  @doc """
  Returns all loaded modules whose names live under `prefix`.
  Example: `modules_under(MasarykEx.Commands)` finds
  `MasarykEx.Commands.Hello`, `MasarykEx.Commands.RestaurantMenus`, etc.
  """
  def modules_under(prefix) when is_atom(prefix) do
    prefix_str = Atom.to_string(prefix)

    modules =
      case Application.spec(:masaryk_ex, :modules) do
        nil -> []
        mods -> mods
      end

    modules
    |> Enum.filter(fn mod ->
      mod_str = Atom.to_string(mod)
      String.starts_with?(mod_str, prefix_str <> ".")
    end)
    |> Enum.filter(&Code.ensure_loaded?/1)
  end

  @doc """
  Returns modules under a prefix that export a specific function/arity.
  """
  def modules_with_function(prefix, fun, arity) do
    modules_under(prefix)
    |> Enum.filter(&function_exported?(&1, fun, arity))
  end
end
