defmodule MasarykEx.Services.Presence.Definition do
  @moduledoc "Rich presence"

  use MasarykEx.Core.Service
  alias MasarykEx.Core.Event

  require Logger

  @impl true
  def handle_event(%Event{type: :interval5m}, _config) do
    update_status()
    :ok
  end

  def handle_event(_event, _config), do: :ok

  def update_status do
    # az bude update na Nostrum v0.11, bude treba upravit
    commands = MasarykEx.Controls.list_commands() |> length

    # Nostrum je trochu retarded, melo by se pouzivat Nostrum.Api.Self.update_status, ale to ignoruje errory
    # Should also be more dynamic - gets called once every 5 minutes, would be nice to have a more descriptive status
    Nostrum.Shard.Supervisor.update_status(
      "online",
      "/help | watching " <> Integer.to_string(commands) <> " commands!",
      nil,
      2
    )
  end
end
