defmodule MasarykExWeb.Components do
  @moduledoc """
  Shared function components for the authenticated dashboard pages.
  """

  use Phoenix.Component

  @doc "Outer page wrapper shared by the dashboard LiveViews."
  slot :inner_block, required: true

  def page(assigns) do
    ~H"""
    <div style="font-family: sans-serif; max-width: 640px; margin: 40px auto; padding: 0 16px;">
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc "Top nav with page links and the signed-in user / log out."
  attr :active, :atom, required: true, doc: ":stats, :controls or :starboard"
  attr :current_user, :map, required: true

  def nav(assigns) do
    ~H"""
    <nav style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; font-size: 0.9rem;">
      <div>
        <%= if @active == :stats do %>
          <span style="font-weight: bold;">Stats</span>
        <% else %>
          <a href="/stats" style="color: #5865F2; text-decoration: none;">Stats</a>
        <% end %>
        <span style="color: #ccc; margin: 0 8px;">·</span>
        <%= if @active == :controls do %>
          <span style="font-weight: bold;">Controls</span>
        <% else %>
          <a href="/controls" style="color: #5865F2; text-decoration: none;">Controls</a>
        <% end %>
        <span style="color: #ccc; margin: 0 8px;">·</span>
        <%= if @active == :starboard do %>
          <span style="font-weight: bold;">Starboard</span>
        <% else %>
          <a href="/starboard" style="color: #5865F2; text-decoration: none;">Starboard</a>
        <% end %>
      </div>
      <div style="color: #999;">
        Signed in as <strong><%= @current_user.username %></strong>
        <span style="color: #ccc; margin: 0 8px;">·</span>
        <a href="/logout" style="color: #5865F2; text-decoration: none;">Log out</a>
      </div>
    </nav>
    """
  end
end
