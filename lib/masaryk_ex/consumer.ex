defmodule MasarykEx.Consumer do
  use Nostrum.Consumer

  alias Nostrum.Api.ApplicationCommand
  alias Nostrum.Api.Interaction
  alias MasarykEx.Autoloader
  alias MasarykEx.Command

  require Logger

  # TODO: replace with your dev guild ID, or load from config/env
  @ready_guild_id 1509892948752339017

  @impl true
  def handle_event({:READY, _payload, _ws_state}) do
    Logger.info("Bot ready. Registering slash commands...")

    command_defs =
      Autoloader.modules_with_function(MasarykEx.Commands, :definition, 0)
      |> Enum.map(& &1.definition())

    case ApplicationCommand.bulk_overwrite_guild_commands(@ready_guild_id, command_defs) do
      {:ok, registered} ->
        names = Enum.map(registered, & &1["name"])
        Logger.info("Registered commands: #{inspect(names)}")

      error ->
        Logger.error("Failed to register commands: #{inspect(error)}")
    end

    :ok
  end

  @impl true
  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) do
    command_name = interaction.data.name
    module = Command.to_module(command_name)

    if Code.ensure_loaded?(module) and function_exported?(module, :handle, 1) do
      response = module.handle(interaction)
      Interaction.create_response(interaction, response)
    else
      Logger.warning("Unknown or unimplemented command: #{command_name} -> #{module}")

      Interaction.create_response(interaction, %{
        type: 4,
        data: %{content: "Unknown command."}
      })
    end
  end

  @impl true
  def handle_event({event_type, payload, ws_state}) do
    Autoloader.modules_with_function(MasarykEx.Services, :handle_event, 3)
    |> Enum.each(fn module ->
      Task.start(fn ->
        try do
          module.handle_event(event_type, payload, ws_state)
        rescue
          err ->
            Logger.error("Service #{module} crashed: #{inspect(err)}")
        end
      end)
    end)

    :ok
  end

  @impl true
  def handle_event(_event) do
    :ok
  end
end
