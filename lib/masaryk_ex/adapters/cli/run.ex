defmodule Mix.Tasks.Bot.Run do
  @shortdoc "Run a bot command from the terminal"

  @moduledoc """
  Run any command through the same core the Discord bot uses, from the terminal.

      mix bot.run hello
      mix bot.run restaurant-menus
      mix bot.run config set restaurant-menus restaurants '["A","B"]'
      mix bot.run config --feature restaurant-menus --action list

  Positional arguments fill the command's declared args in order; `--name value`
  sets one by name. Starts the app with Discord disabled, so no bot token or
  gateway connection is needed.
  """

  use Mix.Task

  alias MasarykEx.Core.{Command, Context, Dispatcher, Request}

  @impl true
  def run(argv) do
    System.put_env("DISCORD_ENABLED", "false")
    Application.put_env(:masaryk_ex, :discord_enabled, false)
    Mix.Task.run("app.start")

    case argv do
      [] ->
        Mix.shell().info("Usage: mix bot.run <command> [--key value ...] [args]")

      [command | rest] ->
        request = %Request{
          command: command,
          args: parse_args(command, rest),
          context: %Context{interface: :cli}
        }

        Mix.shell().info(Dispatcher.run(request).content)
    end
  end

  defp parse_args(command, argv) do
    {flags, positionals} = split_flags(argv, %{}, [])
    names = command |> arg_names() |> Enum.reject(&Map.has_key?(flags, &1))

    names
    |> Enum.zip(positionals)
    |> Map.new()
    |> Map.merge(flags)
  end

  defp arg_names(command) do
    module = Command.to_module(command)

    if Code.ensure_loaded?(module) and function_exported?(module, :definition, 0) do
      module.definition() |> Map.get(:args, []) |> Enum.map(& &1.name)
    else
      []
    end
  end

  defp split_flags([], flags, positionals), do: {flags, Enum.reverse(positionals)}

  defp split_flags(["--" <> name, value | rest], flags, positionals),
    do: split_flags(rest, Map.put(flags, name, value), positionals)

  defp split_flags(["--" <> name], flags, positionals),
    do: split_flags([], Map.put(flags, name, "true"), positionals)

  defp split_flags([token | rest], flags, positionals),
    do: split_flags(rest, flags, [token | positionals])
end
