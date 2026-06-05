defmodule MasarykEx.Core.Dispatcher do
  @moduledoc """
  Single entry point every adapter funnels command invocations through. Finds
  the command module for a `%Request{}`, checks it's enabled, runs it, and
  returns a `%Response{}`, keeping unknown/disabled/crash handling identical
  across all interfaces.
  """

  alias MasarykEx.Core.{Command, Request, Response}

  require Logger

  @spec run(Request.t()) :: Response.t()
  def run(%Request{command: name, context: context} = request) do
    module = Command.to_module(name)

    cond do
      not command?(module) ->
        Logger.warning("Unknown command: #{name} -> #{inspect(module)}")
        Response.text("Unknown command: #{name}", ephemeral: true)

      not MasarykEx.Config.get(module, :enabled, context) ->
        Response.text("The `#{name}` command is currently disabled.", ephemeral: true)

      true ->
        run_command(module, request)
    end
  end

  defp run_command(module, request) do
    case module.run(request) do
      %Response{} = response -> response
      other -> raise "#{inspect(module)}.run/1 must return a %Response{}, got: #{inspect(other)}"
    end
  rescue
    err ->
      Logger.error("Command #{inspect(module)} crashed: #{Exception.message(err)}")
      Response.text("Something went wrong running that command.", ephemeral: true)
  end

  defp command?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :run, 1)
  end
end
