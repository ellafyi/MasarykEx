defmodule MasarykEx.Commands.Config.Definition do
  @moduledoc """
  View and change feature settings. A normal command, so it works identically
  from Discord and the CLI. Writes go to the per-guild scope when a guild is in
  context, otherwise global; pass `scope` to force one.
  """

  use MasarykEx.Core.Command

  alias MasarykEx.Config
  alias MasarykEx.Config.Store
  alias MasarykEx.Core.{Request, Response}

  @impl true
  def definition do
    %{
      name: "config",
      description: "View or change feature settings",
      args: [
        %{name: "action", type: :string, required: true, description: "get | set | unset | list"},
        %{name: "feature", type: :string, required: false, description: "Feature, e.g. restaurant-menus"},
        %{name: "key", type: :string, required: false, description: "Setting key"},
        %{name: "value", type: :string, required: false, description: "New value (JSON or text)"},
        %{name: "scope", type: :string, required: false, description: "global | guild"}
      ]
    }
  end

  @impl true
  def run(%Request{args: args, context: context}) do
    case Map.get(args, "action") do
      "list" -> list(args, context)
      "get" -> get(args, context)
      "set" -> set(args, context)
      "unset" -> unset(args, context)
      other -> reply("Unknown action #{inspect(other)}. Use get | set | unset | list.")
    end
  end

  defp list(args, context) do
    with_feature(args, fn module, name ->
      lines = Enum.map_join(Config.all(module, context), "\n", fn {k, v} -> "  #{k} = #{inspect(v)}" end)
      reply("#{name}:\n#{lines}")
    end)
  end

  defp get(args, context) do
    with_feature(args, fn module, name ->
      case Map.get(args, "key") do
        nil -> reply("get requires a key.")
        key -> reply("#{name}.#{key} = #{inspect(Config.get(module, String.to_atom(key), context))}")
      end
    end)
  end

  defp set(args, context) do
    with_feature(args, fn module, name ->
      with key when is_binary(key) <- Map.get(args, "key"),
           raw when is_binary(raw) <- Map.get(args, "value"),
           {:ok, scope} <- scope(args, context) do
        Store.put(feature_id(module), key, scope, parse_value(raw))
        reply("Set #{name}.#{key} = #{raw} (scope: #{scope})")
      else
        {:error, message} -> reply(message)
        _ -> reply("set requires key and value.")
      end
    end)
  end

  defp unset(args, context) do
    with_feature(args, fn module, name ->
      with key when is_binary(key) <- Map.get(args, "key"),
           {:ok, scope} <- scope(args, context) do
        Store.delete(feature_id(module), key, scope)
        reply("Unset #{name}.#{key} (scope: #{scope})")
      else
        {:error, message} -> reply(message)
        _ -> reply("unset requires a key.")
      end
    end)
  end

  defp with_feature(args, fun) do
    name = Map.get(args, "feature")

    case resolve_module(name) do
      nil -> reply("Unknown feature: #{inspect(name)}")
      module -> fun.(module, name)
    end
  end

  defp resolve_module(nil), do: nil

  defp resolve_module(name) do
    module_name = name |> String.split("-") |> Enum.map_join(&String.capitalize/1)

    [
      Module.concat([MasarykEx.Commands, module_name, "Definition"]),
      Module.concat([MasarykEx.Services, module_name, "Definition"])
    ]
    |> Enum.find(&Code.ensure_loaded?/1)
  end

  defp scope(args, context) do
    case Map.get(args, "scope") do
      "global" -> {:ok, "global"}
      "guild" when is_binary(context.guild_id) -> {:ok, context.guild_id}
      "guild" -> {:error, "No guild in this context; use scope: global."}
      nil -> {:ok, context.guild_id || "global"}
      other -> {:error, "Unknown scope: #{other}"}
    end
  end

  defp parse_value(raw) do
    case Jason.decode(raw) do
      {:ok, value} -> value
      _ -> raw
    end
  end

  defp feature_id(module), do: inspect(module)

  defp reply(text), do: Response.text(text, ephemeral: true)
end
