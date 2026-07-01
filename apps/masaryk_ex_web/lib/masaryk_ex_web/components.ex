# apps/masaryk_ex_web/lib/masaryk_ex_web/components.ex
defmodule MasarykExWeb.Components do
  @moduledoc """
  Shared function components for the authenticated dashboard pages.
  """

  use Phoenix.Component

  alias MasarykEx.Discord

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
  attr :active, :atom, required: true, doc: ":stats, :controls, :starboard or :backup"
  attr :current_user, :map, required: true

  def nav(assigns) do
    assigns = assign(assigns, :guilds, Discord.list_guilds())

    ~H"""
    <nav style="margin-bottom: 24px; font-size: 0.9rem;">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;">
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
            <a href={"/starboard/#{@guild_id}"} style="color: #5865F2; text-decoration: none;">Starboard</a>
          <% end %>
          <span style="color: #ccc; margin: 0 8px;">·</span>
          <%= if @active == :backup do %>
            <span style="font-weight: bold;">Backup</span>
          <% else %>
            <a href="/backup" style="color: #5865F2; text-decoration: none;">Backup</a>
          <% end %>
        </div>
        <div style="color: #999;">
          Signed in as <strong><%= @current_user.username %></strong>
          <span style="color: #ccc; margin: 0 8px;">·</span>
          <a href="/logout" style="color: #5865F2; text-decoration: none;">Log out</a>
        </div>
      </div>
      <%= if @guilds != [] do %>
        <div style="padding: 12px; background: #f9f9f9; border-radius: 4px; border: 1px solid #e0e0e0;">
          <form phx-change="change_guild" style="display: flex; align-items: center; gap: 12px;">
            <label style="color: #666; font-size: 0.9rem; white-space: nowrap;">
              Guild:
            </label>
            <select
              name="guild_id"
              style="flex: 1; padding: 6px 10px; border: 1px solid #ccc; border-radius: 4px; font-size: 0.9rem; background: #fff;"
            >
              <%= for guild <- @guilds do %>
                <option value={guild.id} selected={guild.id == @guild_id}>
                  <%= guild.name %>
                </option>
              <% end %>
            </select>
          </form>
        </div>
      <% end %>
    </nav>
    """
  end
end
