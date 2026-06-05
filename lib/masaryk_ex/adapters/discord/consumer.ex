defmodule MasarykEx.Adapters.Discord.Consumer do
  @moduledoc """
  Discord gateway adapter. Registers slash commands from neutral command
  definitions, turns interactions into Requests for the `Dispatcher`, and
  forwards other gateway events to the `Router` as neutral Events.
  """

  use Nostrum.Consumer

  alias Nostrum.Api.ApplicationCommand
  alias Nostrum.Api.Interaction

  alias MasarykEx.Autoloader
  alias MasarykEx.Core.{Dispatcher, Router}
  alias MasarykEx.Adapters.Discord.Translate

  require Logger

  @impl true
  def handle_event({:READY, _payload, _ws_state}) do
    case guild_id() do
      nil ->
        Logger.warning("DISCORD_GUILD_ID not set, skipping slash command registration.")

      guild_id ->
        register_commands(guild_id)
    end

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

  defp register_commands(guild_id) do
    defs =
      Autoloader.modules_with_function(MasarykEx.Commands, :definition, 0)
      |> Enum.map(&Translate.command_to_discord(&1.definition()))

    case ApplicationCommand.bulk_overwrite_guild_commands(guild_id, defs) do
      {:ok, registered} ->
        Logger.info("Registered commands: #{inspect(Enum.map(registered, & &1["name"]))}")

      error ->
        Logger.error("Failed to register commands: #{inspect(error)}")
    end
  end

  defp guild_id, do: Application.get_env(:masaryk_ex, :discord_guild_id)
end
