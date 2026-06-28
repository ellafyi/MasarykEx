defmodule MasarykExWeb.Live.StarboardLive do
  use Phoenix.LiveView

  import MasarykExWeb.Components

  alias MasarykEx.Starboard

  @per_page 20

  @blank_form %{
    "name" => "",
    "target_channel_id" => "",
    "include_channel_ids" => "",
    "exclude_channel_ids" => "",
    "threshold" => "3",
    "thread_threshold" => "3",
    "position" => "0",
    "enabled" => "true"
  }

  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(MasarykEx.PubSub, Starboard.topic())

    {:ok,
     socket
     |> assign(
       per_page: @per_page,
       editing: nil,
       form: @blank_form,
       error: nil,
       filter_starboard: nil,
       starboards: Starboard.list_starboards()
     )
     |> load_page(1)}
  end

  def handle_event("create_starboard", params, socket) do
    case Starboard.create_starboard(form_to_attrs(params)) do
      {:ok, _board} ->
        {:noreply,
         socket
         |> assign(starboards: Starboard.list_starboards(), form: @blank_form, error: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, form: params, error: changeset_error(changeset))}
    end
  end

  def handle_event("update_starboard", params, socket) do
    case socket.assigns.editing && Starboard.get_starboard(socket.assigns.editing) do
      nil ->
        {:noreply, assign(socket, editing: nil, form: @blank_form, error: nil)}

      board ->
        case Starboard.update_starboard(board, form_to_attrs(params)) do
          {:ok, _board} ->
            {:noreply,
             assign(socket,
               starboards: Starboard.list_starboards(),
               editing: nil,
               form: @blank_form,
               error: nil
             )}

          {:error, changeset} ->
            {:noreply, assign(socket, form: params, error: changeset_error(changeset))}
        end
    end
  end

  def handle_event("edit_starboard", %{"id" => id}, socket) do
    case Starboard.get_starboard(id) do
      nil ->
        {:noreply, socket}

      board ->
        {:noreply, assign(socket, editing: board.id, form: board_to_form(board), error: nil)}
    end
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing: nil, form: @blank_form, error: nil)}
  end

  def handle_event("delete_starboard", %{"id" => id}, socket) do
    case Starboard.get_starboard(id) do
      nil -> :ok
      board -> Starboard.delete_starboard(board)
    end

    {:noreply,
     socket
     |> assign(starboards: Starboard.list_starboards(), editing: nil, form: @blank_form)
     |> load_page(socket.assigns.page)}
  end

  def handle_event("filter_board", %{"starboard_id" => id}, socket) do
    {:noreply, socket |> assign(filter_starboard: parse_filter(id)) |> load_page(1)}
  end

  def handle_event("page", %{"to" => to}, socket) do
    {:noreply, load_page(socket, parse_int(to, socket.assigns.page))}
  end

  def handle_info({:starboard, _}, socket) do
    {:noreply,
     socket
     |> assign(starboards: Starboard.list_starboards())
     |> load_page(socket.assigns.page)}
  end

  defp load_page(socket, page) do
    per_page = socket.assigns[:per_page] || @per_page
    opts = filter_opts(socket)
    total = Starboard.count(opts)
    total_pages = max(div(total + per_page - 1, per_page), 1)
    page = page |> max(1) |> min(total_pages)

    entries = Starboard.list(opts ++ [limit: per_page, offset: (page - 1) * per_page])

    assign(socket, entries: entries, page: page, total: total, total_pages: total_pages)
  end

  defp filter_opts(socket) do
    case socket.assigns[:filter_starboard] do
      nil -> []
      id -> [starboard_id: id]
    end
  end

  defp board_to_form(board) do
    %{
      "name" => board.name,
      "target_channel_id" => board.target_channel_id,
      "include_channel_ids" => Enum.join(board.include_channel_ids, ", "),
      "exclude_channel_ids" => Enum.join(board.exclude_channel_ids, ", "),
      "threshold" => to_string(board.threshold),
      "thread_threshold" => to_string(board.thread_threshold),
      "position" => to_string(board.position),
      "enabled" => board.enabled
    }
  end

  defp form_to_attrs(params) do
    %{
      name: blank_to_nil(params["name"]),
      target_channel_id: blank_to_nil(params["target_channel_id"]),
      include_channel_ids: parse_ids(params["include_channel_ids"]),
      exclude_channel_ids: parse_ids(params["exclude_channel_ids"]),
      threshold: parse_int(params["threshold"], 3),
      thread_threshold: parse_int(params["thread_threshold"], 3),
      position: parse_int(params["position"], 0),
      enabled: checked?(params["enabled"])
    }
  end

  defp parse_ids(value) do
    value
    |> to_string()
    |> String.split(~r/[,\s]+/, trim: true)
  end

  defp parse_int(value, fallback) do
    case Integer.parse(to_string(value)) do
      {n, _} -> n
      _ -> fallback
    end
  end

  defp parse_filter(""), do: nil

  defp parse_filter(id) do
    case Integer.parse(id) do
      {n, _} -> n
      _ -> nil
    end
  end

  defp blank_to_nil(value) do
    case String.trim(to_string(value)) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp checked?(value), do: value in [true, "true", "on"]

  defp changeset_error(changeset) do
    Enum.map_join(changeset.errors, "; ", fn {field, {msg, _opts}} -> "#{field} #{msg}" end)
  end

  defp board_name(nil, _starboards), do: "Unassigned"

  defp board_name(starboard_id, starboards) do
    case Enum.find(starboards, &(&1.id == starboard_id)) do
      nil -> "Unassigned"
      board -> board.name
    end
  end

  defp jump_url(entry) do
    guild = entry.guild_id || "@me"
    "https://discord.com/channels/#{guild}/#{entry.channel_id}/#{entry.message_id}"
  end

  defp excerpt(nil), do: ""
  defp excerpt(content) when byte_size(content) <= 120, do: content
  defp excerpt(content), do: String.slice(content, 0, 117) <> "…"

  defp media_label("video"), do: "View video"
  defp media_label("image"), do: "View image"
  defp media_label(_), do: "View media"

  def render(assigns) do
    ~H"""
    <.page>
      <.nav active={:starboard} current_user={@current_user} />

      <h1 style="font-size: 1.5rem; margin-bottom: 8px;">Starboard</h1>
      <p style="color: #666; margin-top: 0; margin-bottom: 24px;">
        Boards route reacted messages to a target channel. Each board has channel
        include/exclude filters and separate thresholds for normal channels and
        threads/forums. Most-specific board wins; one board per message.
      </p>

      <%= if @error do %>
        <p style="color: #c0392b; background: #fdecea; padding: 8px 12px; border-radius: 4px;">
          <%= @error %>
        </p>
      <% end %>

      <section style="margin-bottom: 32px;">
        <h2 style="font-size: 1.1rem; margin-bottom: 12px;">Boards</h2>

        <%= if @starboards == [] do %>
          <p style="color: #999;">No boards yet. Create one below.</p>
        <% else %>
          <%= for board <- @starboards do %>
            <div style="border: 1px solid #ddd; border-radius: 4px; padding: 12px 16px; margin-bottom: 12px;">
              <div style="display: flex; justify-content: space-between; align-items: baseline;">
                <strong style="font-size: 1rem;"><%= board.name %></strong>
                <span>
                  <button
                    phx-click="edit_starboard"
                    phx-value-id={board.id}
                    style="padding: 4px 12px; border: 1px solid #ccc; border-radius: 4px; background: #fff; color: #5865F2; cursor: pointer;"
                  >
                    Edit
                  </button>
                  <button
                    phx-click="delete_starboard"
                    phx-value-id={board.id}
                    data-confirm={"Delete board \"#{board.name}\"?"}
                    style="padding: 4px 12px; border: 1px solid #e0b4b4; border-radius: 4px; background: #fff; color: #c0392b; cursor: pointer;"
                  >
                    Delete
                  </button>
                </span>
              </div>
              <div style="color: #666; font-size: 0.85rem; margin-top: 6px;">
                Target: <code>&lt;#<%= board.target_channel_id %>&gt;</code>
                <span style="color: #ccc; margin: 0 6px;">·</span>
                Include: <%= filters_text(board.include_channel_ids) %>
                <span style="color: #ccc; margin: 0 6px;">·</span>
                Exclude: <%= filters_text(board.exclude_channel_ids) %>
              </div>
              <div style="color: #666; font-size: 0.85rem; margin-top: 4px;">
                Threshold: <%= board.threshold %>
                <span style="color: #ccc; margin: 0 6px;">·</span>
                Thread/forum threshold: <%= board.thread_threshold %>
                <span style="color: #ccc; margin: 0 6px;">·</span>
                Position: <%= board.position %>
                <span style="color: #ccc; margin: 0 6px;">·</span>
                <%= if board.enabled, do: "Enabled", else: "Disabled" %>
              </div>
            </div>
          <% end %>
        <% end %>
      </section>

      <section style="margin-bottom: 32px; padding: 16px; background: #f9f9f9; border-radius: 4px;">
        <h2 style="font-size: 1.1rem; margin-top: 0; margin-bottom: 12px;">
          <%= if @editing, do: "Edit board", else: "New board" %>
        </h2>

        <form
          id="starboard-form"
          phx-submit={if @editing, do: "update_starboard", else: "create_starboard"}
        >
          <div style="display: flex; flex-direction: column; gap: 12px;">
            <label>
              <div style="color: #666; font-size: 0.85rem; margin-bottom: 4px;">Name</div>
              <input
                type="text"
                name="name"
                value={@form["name"]}
                placeholder="e.g. Memes"
                style="padding: 6px 10px; border: 1px solid #ccc; border-radius: 4px; width: 100%; box-sizing: border-box;"
              />
            </label>
            <label>
              <div style="color: #666; font-size: 0.85rem; margin-bottom: 4px;">Target channel ID</div>
              <input
                type="text"
                name="target_channel_id"
                value={@form["target_channel_id"]}
                placeholder="e.g. 123456789012345678"
                style="padding: 6px 10px; border: 1px solid #ccc; border-radius: 4px; width: 100%; box-sizing: border-box;"
              />
            </label>
            <label>
              <div style="color: #666; font-size: 0.85rem; margin-bottom: 4px;">
                Include channel IDs (comma/space separated; empty = all channels)
              </div>
              <input
                type="text"
                name="include_channel_ids"
                value={@form["include_channel_ids"]}
                placeholder="e.g. 111, 222"
                style="padding: 6px 10px; border: 1px solid #ccc; border-radius: 4px; width: 100%; box-sizing: border-box;"
              />
            </label>
            <label>
              <div style="color: #666; font-size: 0.85rem; margin-bottom: 4px;">
                Exclude channel IDs (comma/space separated)
              </div>
              <input
                type="text"
                name="exclude_channel_ids"
                value={@form["exclude_channel_ids"]}
                placeholder="e.g. 333"
                style="padding: 6px 10px; border: 1px solid #ccc; border-radius: 4px; width: 100%; box-sizing: border-box;"
              />
            </label>
            <div style="display: flex; gap: 16px; flex-wrap: wrap;">
              <label>
                <div style="color: #666; font-size: 0.85rem; margin-bottom: 4px;">Threshold</div>
                <input
                  type="number"
                  name="threshold"
                  min="1"
                  value={@form["threshold"]}
                  style="padding: 6px 10px; border: 1px solid #ccc; border-radius: 4px; width: 110px;"
                />
              </label>
              <label>
                <div style="color: #666; font-size: 0.85rem; margin-bottom: 4px;">Thread/forum threshold</div>
                <input
                  type="number"
                  name="thread_threshold"
                  min="1"
                  value={@form["thread_threshold"]}
                  style="padding: 6px 10px; border: 1px solid #ccc; border-radius: 4px; width: 110px;"
                />
              </label>
              <label>
                <div style="color: #666; font-size: 0.85rem; margin-bottom: 4px;">Position</div>
                <input
                  type="number"
                  name="position"
                  value={@form["position"]}
                  style="padding: 6px 10px; border: 1px solid #ccc; border-radius: 4px; width: 90px;"
                />
              </label>
              <label style="display: flex; align-items: center; gap: 6px; align-self: flex-end; padding-bottom: 8px;">
                <input type="hidden" name="enabled" value="false" />
                <input type="checkbox" name="enabled" value="true" checked={checked?(@form["enabled"])} />
                <span style="color: #666; font-size: 0.85rem;">Enabled</span>
              </label>
            </div>
            <div>
              <button
                type="submit"
                style="padding: 7px 16px; border: none; border-radius: 4px; cursor: pointer; color: #fff; font-weight: bold; background: #5865F2;"
              >
                <%= if @editing, do: "Update board", else: "Create board" %>
              </button>
              <%= if @editing do %>
                <button
                  type="button"
                  phx-click="cancel_edit"
                  style="padding: 7px 16px; border: 1px solid #ccc; border-radius: 4px; cursor: pointer; background: #fff; color: #666;"
                >
                  Cancel
                </button>
              <% end %>
            </div>
          </div>
        </form>
      </section>

      <h2 style="font-size: 1.1rem; margin-bottom: 12px;">Starred messages</h2>

      <form id="starboard-filter" phx-change="filter_board" style="margin-bottom: 16px;">
        <label>
          <span style="color: #666; font-size: 0.85rem; margin-right: 8px;">Board</span>
          <select name="starboard_id" style="padding: 6px 10px; border: 1px solid #ccc; border-radius: 4px;">
            <option value="" selected={@filter_starboard == nil}>All boards</option>
            <%= for board <- @starboards do %>
              <option value={board.id} selected={@filter_starboard == board.id}>
                <%= board.name %>
              </option>
            <% end %>
          </select>
        </label>
      </form>

      <%= if @entries == [] do %>
        <p style="color: #999;">No starred messages yet.</p>
      <% else %>
        <table style="width: 100%; border-collapse: collapse;">
          <thead>
            <tr style="text-align: left; border-bottom: 1px solid #ddd;">
              <th style="padding: 8px 0;">Author</th>
              <th style="padding: 8px 0;">Message</th>
              <th style="padding: 8px 0;">Board</th>
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
                  <%= if entry.media_url do %>
                    <span style="color: #ccc; margin: 0 6px;">·</span>
                    <a href={entry.media_url} target="_blank" style="color: #5865F2; text-decoration: none; font-size: 0.85rem;">
                      <%= media_label(entry.media_type) %>
                    </a>
                  <% end %>
                </td>
                <td style="padding: 12px 8px 12px 0; vertical-align: top; white-space: nowrap; color: #666; font-size: 0.85rem;">
                  <%= board_name(entry.starboard_id, @starboards) %>
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

  defp filters_text([]), do: "all"
  defp filters_text(ids), do: Enum.join(ids, ", ")

  defp pager_style(disabled) do
    base = "padding: 6px 14px; border: 1px solid #ccc; border-radius: 4px; background: #fff;"

    if disabled,
      do: base <> " color: #ccc; cursor: default;",
      else: base <> " color: #5865F2; cursor: pointer;"
  end
end
