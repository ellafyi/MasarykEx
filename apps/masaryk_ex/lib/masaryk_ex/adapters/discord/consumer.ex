defmodule MasarykEx.Adapters.Discord.Consumer do
  @moduledoc """
  Discord gateway adapter. Registers slash commands from neutral command
  definitions, turns interactions into Requests for the `Dispatcher`, and
  forwards other gateway events to the `Router` as neutral Events.
  """

  use Nostrum.Consumer

  alias Nostrum.Api.ApplicationCommand
  alias Nostrum.Api.Interaction
  alias Nostrum.Struct.Event.Ready

  alias MasarykEx.Autoloader
  alias MasarykEx.Core.{Dispatcher, Router}
  alias MasarykEx.Adapters.Discord.Translate

  require Logger

  @impl true
  @spec handle_event({:READY, Ready.t(), any()}) :: :ok
  def handle_event({:READY, payload, _ws_state}) do
    Logger.debug("DISCORD_READY: #{inspect(payload)}")

    Logger.info("Starting as discord user #{payload.user.username}")

    payload.guilds
    |> Enum.each(fn guild ->
      register_commands(guild.id)
    end)

    :ok
  end

  @impl true
  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) do
    response =
      interaction
      |> Translate.to_request()
      |> Dispatcher.run()
      |> Translate.to_discord_response()

    Interaction.create_response(interaction, response)
  end

  @impl true
  def handle_event({event_type, payload, _ws_state}) do
    case Translate.to_event(event_type, payload) do
      nil -> :ok
      event -> Router.dispatch(event)
    end
  end

  @impl true
  def handle_event(_event), do: :ok

  def register_commands(guild_id) do
    Logger.debug("Registering commands for guild #{guild_id}")

    defs =
      Autoloader.modules_with_function(MasarykEx.Commands, :definition, 0)
      |> Enum.map(&Translate.command_to_discord(&1.definition()))

    case ApplicationCommand.bulk_overwrite_guild_commands(guild_id, defs) do
      {:ok, _registered} ->
        Logger.info("Registered commands: #{inspect(Enum.map(defs, & &1.name))}")

      error ->
        Logger.error("Failed to register commands: #{inspect(error)}")
    end
  end
end
