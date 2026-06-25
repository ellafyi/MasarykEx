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
    render_page(conn, :login)
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
    |> render_page(:forbidden)
  end

  # Render a standalone auth page (MasarykExWeb.AuthHTML) with no layouts, so the
  # live root layout's socket script stays off these non-live pages.
  defp render_page(conn, template) do
    conn
    |> put_root_layout(html: false)
    |> put_layout(html: false)
    |> render(template)
  end
end
