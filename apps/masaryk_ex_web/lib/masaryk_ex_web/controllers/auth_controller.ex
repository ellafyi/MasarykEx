defmodule MasarykExWeb.AuthController do
  @moduledoc """
  Discord OAuth2 login for the dashboard.

    * `login`    — a minimal page with a "Sign in with Discord" button
    * `request`  — store a CSRF `state`, redirect to Discord's consent screen
    * `callback` — verify state, identify the user, check their guild role
    * `logout`   — drop the session

  Pages are sent as plain HTML (not rendered through the live root layout) so the
  LiveView socket script isn't pulled onto these non-live pages.
  """

  use Phoenix.Controller, formats: [:html]

  import Plug.Conn

  alias MasarykEx.Discord
  alias MasarykExWeb.Auth

  def login(conn, _params) do
    html(conn, login_page())
  end

  def request(conn, _params) do
    state = Auth.gen_state()

    conn
    |> put_session(:oauth_state, state)
    |> redirect(external: Discord.OAuth.authorize_url(state))
  end

  def callback(conn, %{"code" => code, "state" => state}) do
    expected = get_session(conn, :oauth_state)
    conn = delete_session(conn, :oauth_state)

    with true <- Auth.valid_state?(expected, state),
         {:ok, user} <- Discord.OAuth.fetch_user(code),
         true <- Discord.stats_authorized?(user.id) do
      conn
      # Renew the session id on privilege change (anti session-fixation).
      |> configure_session(renew: true)
      |> put_session(:user_id, user.id)
      |> put_session(:username, user.username)
      |> redirect(to: "/stats")
    else
      _ -> forbidden(conn)
    end
  end

  def callback(conn, _params), do: forbidden(conn)

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> configure_session(drop: true)
    |> redirect(to: "/login")
  end

  defp forbidden(conn) do
    conn
    |> put_status(:forbidden)
    |> html(forbidden_page())
  end

  defp login_page do
    page("""
    <h1>MasarykEx Dashboard</h1>
    <p>Sign in with Discord to view the bot stats.</p>
    <a class="btn" href="/auth/discord">Sign in with Discord</a>
    """)
  end

  defp forbidden_page do
    page("""
    <h1>Access denied</h1>
    <p>Your Discord account doesn't have the role required to view this dashboard.</p>
    <a class="btn" href="/login">Back to sign in</a>
    """)
  end

  defp page(inner) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8"/>
      <meta name="viewport" content="width=device-width, initial-scale=1"/>
      <title>MasarykEx Dashboard</title>
      <style>
        body { font-family: sans-serif; max-width: 480px; margin: 80px auto; padding: 0 16px; text-align: center; }
        h1 { font-size: 1.5rem; }
        p { color: #555; }
        .btn { display: inline-block; margin-top: 16px; padding: 10px 20px; background: #5865F2; color: #fff; border-radius: 6px; text-decoration: none; font-weight: bold; }
      </style>
    </head>
    <body>#{inner}</body>
    </html>
    """
  end
end
