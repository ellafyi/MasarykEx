defmodule MasarykExWeb.Live.StatsLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(MasarykEx.PubSub, "stats")
      :timer.send_interval(1_000, :tick)
    end

    {:ok, assign(socket, load_stats())}
  end

  def handle_info(:tick, socket) do
    {:noreply, assign(socket, uptime_seconds: uptime_seconds())}
  end

  def handle_info(:updated, socket) do
    {:noreply, assign(socket, load_stats())}
  end

  defp load_stats do
    %{started_at: started_at, commands: commands} = MasarykEx.Stats.get()
    sorted_commands = Enum.sort_by(commands, fn {_k, v} -> v end, :desc)
    [uptime_seconds: DateTime.diff(DateTime.utc_now(), started_at), commands: sorted_commands]
  end

  defp uptime_seconds do
    %{started_at: started_at} = MasarykEx.Stats.get()
    DateTime.diff(DateTime.utc_now(), started_at)
  end

  defp format_uptime(seconds) do
    d = div(seconds, 86_400)
    h = div(rem(seconds, 86_400), 3_600)
    m = div(rem(seconds, 3_600), 60)
    s = rem(seconds, 60)

    [if(d > 0, do: "#{d}d"), if(h > 0, do: "#{h}h"), if(m > 0, do: "#{m}m"), "#{s}s"]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  def render(assigns) do
    ~H"""
    <div style="font-family: sans-serif; max-width: 640px; margin: 40px auto; padding: 0 16px;">
      <nav style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; font-size: 0.9rem;">
        <div>
          <span style="font-weight: bold;">Stats</span>
          <span style="color: #ccc; margin: 0 8px;">·</span>
          <a href="/controls" style="color: #5865F2; text-decoration: none;">Controls</a>
        </div>
        <div style="color: #999;">
          Signed in as <strong><%= @current_user.username %></strong>
          <span style="color: #ccc; margin: 0 8px;">·</span>
          <a href="/logout" style="color: #5865F2; text-decoration: none;">Log out</a>
        </div>
      </nav>

      <h1 style="font-size: 1.5rem; margin-bottom: 24px;">Bot Stats</h1>

      <section style="margin-bottom: 32px;">
        <h2 style="font-size: 1rem; color: #666; margin-bottom: 8px;">Uptime</h2>
        <p style="font-size: 2rem; font-weight: bold; margin: 0;"><%= format_uptime(@uptime_seconds) %></p>
      </section>

      <section>
        <h2 style="font-size: 1rem; color: #666; margin-bottom: 8px;">Command invocations</h2>
        <%= if @commands == [] do %>
          <p style="color: #999;">No commands invoked yet.</p>
        <% else %>
          <table style="width: 100%; border-collapse: collapse;">
            <thead>
              <tr style="text-align: left; border-bottom: 1px solid #ddd;">
                <th style="padding: 8px 0;">Command</th>
                <th style="padding: 8px 0; text-align: right;">Invocations</th>
              </tr>
            </thead>
            <tbody>
              <%= for {name, count} <- @commands do %>
                <tr style="border-bottom: 1px solid #f0f0f0;">
                  <td style="padding: 8px 0;"><code><%= name %></code></td>
                  <td style="padding: 8px 0; text-align: right;"><%= count %></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        <% end %>
      </section>
    </div>
    """
  end
end
