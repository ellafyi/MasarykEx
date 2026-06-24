defmodule MasarykExWeb.Live.ControlsLive do
  use Phoenix.LiveView

  alias MasarykEx.Controls

  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(MasarykEx.PubSub, Controls.topic())
    {:ok, assign(socket, commands: Controls.list_commands())}
  end

  def handle_event("toggle", %{"name" => name}, socket) do
    case Enum.find(socket.assigns.commands, &(&1.name == name)) do
      nil ->
        {:noreply, socket}

      cmd ->
        Controls.set_enabled(cmd.module, not cmd.enabled)
        {:noreply, assign(socket, commands: Controls.list_commands())}
    end
  end

  def handle_info({:command_toggled, _module, _enabled}, socket) do
    {:noreply, assign(socket, commands: Controls.list_commands())}
  end

  def render(assigns) do
    ~H"""
    <div style="font-family: sans-serif; max-width: 640px; margin: 40px auto; padding: 0 16px;">
      <nav style="margin-bottom: 24px; font-size: 0.9rem;">
        <a href="/stats" style="color: #5865F2; text-decoration: none;">Stats</a>
        <span style="color: #ccc; margin: 0 8px;">·</span>
        <span style="font-weight: bold;">Controls</span>
      </nav>

      <h1 style="font-size: 1.5rem; margin-bottom: 8px;">Command Controls</h1>
      <p style="color: #666; margin-top: 0; margin-bottom: 24px;">
        Toggle commands on or off. Changes apply immediately, no restart.
      </p>

      <table style="width: 100%; border-collapse: collapse;">
        <thead>
          <tr style="text-align: left; border-bottom: 1px solid #ddd;">
            <th style="padding: 8px 0;">Command</th>
            <th style="padding: 8px 0; text-align: right;">Status</th>
          </tr>
        </thead>
        <tbody>
          <%= for cmd <- @commands do %>
            <tr style="border-bottom: 1px solid #f0f0f0;">
              <td style="padding: 12px 0;">
                <code style="font-weight: bold;"><%= cmd.name %></code>
                <div style="color: #999; font-size: 0.85rem;"><%= cmd.description %></div>
              </td>
              <td style="padding: 12px 0; text-align: right;">
                <button
                  phx-click="toggle"
                  phx-value-name={cmd.name}
                  style={"padding: 4px 14px; border: none; border-radius: 4px; cursor: pointer; color: #fff; font-weight: bold; background: #{if cmd.enabled, do: "#3ba55d", else: "#b0b0b0"};"}
                >
                  <%= if cmd.enabled, do: "Enabled", else: "Disabled" %>
                </button>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end
end
