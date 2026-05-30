defmodule MasarykEx.Consumer do
  use Nostrum.Consumer

  alias Nostrum.Api.Message
  alias Nostrum.Api.ApplicationCommand
  alias Nostrum.Api.Interaction

  @impl true
  def handle_event({:READY, %{guilds: _guilds}, _ws_state}) do
    guild_id = 1509892948752339017
    command = %{
      name: "hello",
      description: "say hello with slash command"
    }

    ApplicationCommand.create_guild_command(guild_id, command)
    :ok
  end

  @impl true
  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) do
    case interaction.data.name do
      "hello" ->
        response = %{
          type: 4,
          data: %{
            content: "Hello from the other side"
          }
        }
        Interaction.create_response(interaction, response)
      _ ->
        :ignore
    end
  end

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    case msg.content do
      "!hello" ->
        {:ok, _message} = Message.create(msg.channel_id, "Hello, world!")

      _ ->
        :ignore
    end
  end
  # Ignore any other events
end
