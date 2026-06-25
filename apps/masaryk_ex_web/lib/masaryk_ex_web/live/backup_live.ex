defmodule MasarykExWeb.Live.BackupLive do
  use Phoenix.LiveView

  import MasarykExWeb.Components

  alias MasarykEx.Backup

  @per_page 25

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(MasarykEx.PubSub, Backup.topic())
      :timer.send_interval(2_000, :tick)
    end

    {:ok,
     socket
     |> assign(settings: Backup.settings(), query: "", page: 1, per_page: @per_page)
     |> load_status()
     |> load_results()}
  end

  def handle_event("toggle", _params, socket) do
    if socket.assigns.running, do: Backup.pause(), else: Backup.start()
    {:noreply, load_status(socket)}
  end

  def handle_event("save_settings", %{"channel_id" => channel_id}, socket) do
    Backup.update_settings(%{channel_id: blank_to_nil(channel_id)})
    {:noreply, assign(socket, settings: Backup.settings())}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, socket |> assign(query: query, page: 1) |> load_results()}
  end

  def handle_event("page", %{"to" => to}, socket) do
    {:noreply, socket |> assign(page: String.to_integer(to)) |> load_results()}
  end

  def handle_info(:tick, socket), do: {:noreply, load_status(socket)}
  def handle_info({:backup, _}, socket), do: {:noreply, socket |> load_status() |> load_results()}

  defp load_status(socket) do
    current = Backup.current_channel()

    assign(socket,
      running: Backup.running?(),
      progress: Backup.progress(),
      total_messages: Backup.total(),
      current_channel: current && (current.name || current.channel_id)
    )
  end

  defp load_results(socket) do
    %{query: query, page: page, per_page: per_page} = socket.assigns
    opts = [query: query]
    total = Backup.count(opts)
    total_pages = max(div(total + per_page - 1, per_page), 1)
    page = page |> max(1) |> min(total_pages)

    results = Backup.search(opts ++ [limit: per_page, offset: (page - 1) * per_page])
    assign(socket, results: results, page: page, result_count: total, total_pages: total_pages)
  end

  defp pct(%{total: 0}), do: 0
  defp pct(%{total: total, done: done}), do: round(done / total * 100)

  defp excerpt(nil), do: ""
  defp excerpt(content) when byte_size(content) <= 140, do: content
  defp excerpt(content), do: String.slice(content, 0, 137) <> "…"

  defp when_at(nil), do: ""
  defp when_at(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")

  defp blank_to_nil(value) do
    case String.trim(to_string(value)) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  def render(assigns) do
    ~H"""
    <.page>
      <.nav active={:backup} current_user={@current_user} />

      <h1 style="font-size: 1.5rem; margin-bottom: 8px;">Message Backup</h1>
      <p style="color: #666; margin-top: 0; margin-bottom: 24px;">
        Archives every message in the server, oldest first, then keeps capturing new
        ones live. Pausing stops the historical backfill only.
      </p>

      <section style="margin-bottom: 24px; padding: 16px; background: #f9f9f9; border-radius: 4px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;">
          <div>
            <strong><%= @total_messages %></strong> messages archived
            <span style="color: #999;">
              · <%= @progress.done %>/<%= @progress.total %> channels
              <%= if @running and @current_channel do %>
                · backing up <strong><%= @current_channel %></strong>
              <% end %>
            </span>
          </div>
          <button
            phx-click="toggle"
            style={"padding: 6px 16px; border: none; border-radius: 4px; cursor: pointer; color: #fff; font-weight: bold; background: #{if @running, do: "#ed4245", else: "#3ba55d"};"}
          >
            <%= if @running, do: "Pause", else: "Start" %>
          </button>
        </div>
        <div style="background: #e0e0e0; border-radius: 4px; height: 10px; overflow: hidden;">
          <div style={"background: #5865F2; height: 10px; width: #{pct(@progress)}%;"}></div>
        </div>
      </section>

      <form id="backup-settings" phx-submit="save_settings" style="margin-bottom: 24px;">
        <label style="color: #666; font-size: 0.85rem;">Activity-log channel ID</label>
        <div style="display: flex; gap: 8px; margin-top: 4px;">
          <input
            type="text"
            name="channel_id"
            value={@settings.channel_id}
            placeholder="e.g. 123456789012345678"
            style="flex: 1; padding: 6px 10px; border: 1px solid #ccc; border-radius: 4px;"
          />
          <button type="submit" style="padding: 6px 16px; border: none; border-radius: 4px; cursor: pointer; color: #fff; background: #5865F2;">
            Save
          </button>
        </div>
      </form>

      <form id="backup-search" phx-submit="search" style="margin-bottom: 16px;">
        <input
          type="text"
          name="query"
          value={@query}
          placeholder="Search archived messages…"
          style="width: 100%; padding: 8px 10px; border: 1px solid #ccc; border-radius: 4px; box-sizing: border-box;"
        />
      </form>

      <p style="color: #999; font-size: 0.85rem;"><%= @result_count %> match<%= if @result_count != 1, do: "es" %></p>

      <%= for msg <- @results do %>
        <div style="padding: 10px 0; border-bottom: 1px solid #f0f0f0;">
          <div style="font-size: 0.8rem; color: #999;">
            <strong style="color: #555;"><%= msg.author_username || msg.author_id %></strong>
            · #<%= msg.channel_id %> · <%= when_at(msg.posted_at) %>
            <%= if msg.edited_at do %><span style="color: #faa61a;">· edited</span><% end %>
            <%= if msg.deleted_at do %><span style="color: #ed4245;">· deleted</span><% end %>
          </div>
          <div><%= excerpt(msg.content) %></div>
        </div>
      <% end %>

      <%= if @result_count > @per_page do %>
        <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 16px; font-size: 0.9rem;">
          <button phx-click="page" phx-value-to={@page - 1} disabled={@page <= 1} style={pager_style(@page <= 1)}>← Prev</button>
          <span style="color: #666;">Page <%= @page %> of <%= @total_pages %></span>
          <button phx-click="page" phx-value-to={@page + 1} disabled={@page >= @total_pages} style={pager_style(@page >= @total_pages)}>Next →</button>
        </div>
      <% end %>
    </.page>
    """
  end

  defp pager_style(disabled) do
    base = "padding: 6px 14px; border: 1px solid #ccc; border-radius: 4px; background: #fff;"
    if disabled, do: base <> " color: #ccc;", else: base <> " color: #5865F2; cursor: pointer;"
  end
end
