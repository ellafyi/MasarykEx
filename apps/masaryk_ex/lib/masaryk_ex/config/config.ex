defmodule MasarykEx.Config do
  @moduledoc """
  Per-feature configuration with layered resolution. `get/3` resolves a setting
  in priority order:

    1. per-guild runtime override (if the context carries a guild_id)
    2. global runtime override
    3. static value from `config.exs`
    4. the feature's `config_schema/0` default

  Overrides (1 & 2) are persisted via `MasarykEx.Config.Store`. `enabled`
  defaults to `true` so every feature is on unless turned off.

  TODO:
  - Should have some way of finding all modules (maybe whitelisting modules?)
  - WebUI for admins
  """

  alias MasarykEx.Core.Context
  alias MasarykEx.Config.Store

  @global "global"

  @doc "Resolve a single config value for `module`/`key` in the given context."
  @spec get(module(), atom(), Context.t()) :: term()
  def get(module, key, %Context{} = context) do
    feature = feature_id(module)
    key_str = Atom.to_string(key)

    with :error <- fetch_override(feature, key_str, context) do
      static_default(module, key)
    else
      {:ok, value} -> value
    end
  end

  @doc "Resolve the full effective config map for `module` (every key, fully layered)."
  @spec all(module(), Context.t()) :: %{atom() => term()}
  def all(module, %Context{} = context) do
    keys =
      [:enabled]
      |> append_keys(schema(module) |> Map.keys())
      |> append_keys(static_config(module) |> Keyword.keys())
      |> append_keys(Store.keys(feature_id(module)) |> Enum.map(&safe_atom/1))
      |> Enum.uniq()

    Map.new(keys, fn key -> {key, get(module, key, context)} end)
  end

  defp fetch_override(feature, key_str, %Context{guild_id: guild_id}) do
    scopes = if guild_id, do: [to_string(guild_id), @global], else: [@global]

    Enum.reduce_while(scopes, :error, fn scope, _acc ->
      case Store.get(feature, key_str, scope) do
        {:ok, value} -> {:halt, {:ok, value}}
        :error -> {:cont, :error}
      end
    end)
  end

  defp static_default(module, key) do
    case Keyword.fetch(static_config(module), key) do
      {:ok, value} ->
        value

      :error ->
        case Map.fetch(schema(module), key) do
          {:ok, value} -> value
          :error -> builtin_default(key)
        end
    end
  end

  defp builtin_default(:enabled), do: true
  defp builtin_default(_), do: nil

  defp static_config(module), do: Application.get_env(:masaryk_ex, module, [])

  defp schema(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :config_schema, 0) do
      module.config_schema()
    else
      %{}
    end
  end

  defp feature_id(module), do: inspect(module)

  defp append_keys(acc, keys), do: acc ++ keys

  # TODO Move to utils or smtg
  # Also, `String.to_atom` can OOM the atom table, are we sure this is safe?
  defp safe_atom(str) do
    String.to_existing_atom(str)
  rescue
    ArgumentError -> String.to_atom(str)
  end
end
