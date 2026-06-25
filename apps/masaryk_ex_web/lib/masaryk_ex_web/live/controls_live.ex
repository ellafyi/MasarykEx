defmodule MasarykExWeb.Live.ControlsLive do
  use Phoenix.LiveView

  import MasarykExWeb.Components

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
    <.page>
      <.nav active={:controls} current_user={@current_user} />

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
    </.page>
    """
  end
end
