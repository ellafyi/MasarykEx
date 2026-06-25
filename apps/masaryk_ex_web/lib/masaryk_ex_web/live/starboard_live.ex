defmodule MasarykExWeb.Live.StarboardLive do
  use Phoenix.LiveView

  import MasarykExWeb.Components

  alias MasarykEx.Starboard

  @per_page 20

  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(MasarykEx.PubSub, Starboard.topic())

    {:ok,
     socket
     |> assign(settings: Starboard.settings(), per_page: @per_page)
     |> load_page(1)}
  end

  def handle_event(
        "save_settings",
        %{"threshold" => threshold, "channel_id" => channel_id},
        socket
      ) do
    Starboard.update_settings(%{
      threshold: parse_threshold(threshold, socket.assigns.settings.threshold),
      channel_id: blank_to_nil(channel_id)
    })

    {:noreply, assign(socket, settings: Starboard.settings())}
  end

  def handle_event("page", %{"to" => to}, socket) do
    {:noreply, load_page(socket, String.to_integer(to))}
  end

  def handle_info({:starboard, _}, socket) do
    {:noreply, load_page(socket, socket.assigns.page)}
  end

  defp load_page(socket, page) do
    per_page = socket.assigns[:per_page] || @per_page
    total = Starboard.count()
    total_pages = max(div(total + per_page - 1, per_page), 1)
    page = page |> max(1) |> min(total_pages)

    entries = Starboard.list(limit: per_page, offset: (page - 1) * per_page)

    assign(socket, entries: entries, page: page, total: total, total_pages: total_pages)
  end

  defp parse_threshold(value, fallback) do
    case Integer.parse(to_string(value)) do
      {n, _} when n > 0 -> n
      _ -> fallback
    end
  end

  defp blank_to_nil(value) do
    case String.trim(to_string(value)) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp jump_url(entry) do
    guild = entry.guild_id || "@me"
    "https://discord.com/channels/#{guild}/#{entry.channel_id}/#{entry.message_id}"
  end

  defp excerpt(nil), do: ""
  defp excerpt(content) when byte_size(content) <= 120, do: content
  defp excerpt(content), do: String.slice(content, 0, 117) <> "…"

  def render(assigns) do
    ~H"""
    <.page>
      <.nav active={:starboard} current_user={@current_user} />

      <h1 style="font-size: 1.5rem; margin-bottom: 8px;">Starboard</h1>
      <p style="color: #666; margin-top: 0; margin-bottom: 24px;">
        Messages that reached the reaction threshold. Changes to the settings below
        apply immediately, no restart.
      </p>

      <form id="starboard-settings" phx-submit="save_settings" style="margin-bottom: 32px; padding: 16px; background: #f9f9f9; border-radius: 4px;">
        <div style="display: flex; gap: 16px; flex-wrap: wrap; align-items: flex-end;">
          <label style="display: block;">
            <div style="color: #666; font-size: 0.85rem; margin-bottom: 4px;">Reaction threshold</div>
            <input
              type="number"
              name="threshold"
              min="1"
              value={@settings.threshold}
              style="padding: 6px 10px; border: 1px solid #ccc; border-radius: 4px; width: 100px;"
            />
          </label>
          <label style="display: block; flex: 1; min-width: 200px;">
            <div style="color: #666; font-size: 0.85rem; margin-bottom: 4px;">Starboard channel ID</div>
            <input
              type="text"
              name="channel_id"
              value={@settings.channel_id}
              placeholder="e.g. 123456789012345678"
              style="padding: 6px 10px; border: 1px solid #ccc; border-radius: 4px; width: 100%; box-sizing: border-box;"
            />
          </label>
          <button
            type="submit"
            style="padding: 7px 16px; border: none; border-radius: 4px; cursor: pointer; color: #fff; font-weight: bold; background: #5865F2;"
          >
            Save
          </button>
        </div>
      </form>

      <%= if @entries == [] do %>
        <p style="color: #999;">No starred messages yet.</p>
      <% else %>
        <table style="width: 100%; border-collapse: collapse;">
          <thead>
            <tr style="text-align: left; border-bottom: 1px solid #ddd;">
              <th style="padding: 8px 0;">Author</th>
              <th style="padding: 8px 0;">Message</th>
              <th style="padding: 8px 0; text-align: right;">Reactions</th>
            </tr>
          </thead>
          <tbody>
            <%= for entry <- @entries do %>
              <tr style="border-bottom: 1px solid #f0f0f0;">
                <td style="padding: 12px 8px 12px 0; vertical-align: top; white-space: nowrap;">
                  <%= entry.author || "—" %>
                </td>
                <td style="padding: 12px 8px 12px 0; vertical-align: top;">
                  <div><%= excerpt(entry.content) %></div>
                  <a href={jump_url(entry)} target="_blank" style="color: #5865F2; text-decoration: none; font-size: 0.85rem;">
                    Jump to message
                  </a>
                </td>
                <td style="padding: 12px 0; text-align: right; vertical-align: top; white-space: nowrap;">
                  <%= entry.emoji %> <%= entry.reaction_count %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>

        <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 16px; font-size: 0.9rem;">
          <button
            phx-click="page"
            phx-value-to={@page - 1}
            disabled={@page <= 1}
            style={pager_style(@page <= 1)}
          >
            ← Prev
          </button>
          <span style="color: #666;">Page <%= @page %> of <%= @total_pages %></span>
          <button
            phx-click="page"
            phx-value-to={@page + 1}
            disabled={@page >= @total_pages}
            style={pager_style(@page >= @total_pages)}
          >
            Next →
          </button>
        </div>
      <% end %>
    </.page>
    """
  end

  defp pager_style(disabled) do
    base = "padding: 6px 14px; border: 1px solid #ccc; border-radius: 4px; background: #fff;"

    if disabled,
      do: base <> " color: #ccc; cursor: default;",
      else: base <> " color: #5865F2; cursor: pointer;"
  end
end
