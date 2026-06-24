defmodule MasarykExWeb.Auth do
  @moduledoc """
  Session-based authentication for the dashboard. After a successful Discord
  login (see `MasarykExWeb.AuthController`) the user's id/username live in the
  signed session; these plugs and the `on_mount` hook gate access on its presence.

  Also provides the CSRF `state` helpers for the OAuth redirect.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  def init(opts), do: opts

  def call(conn, :fetch_current_user), do: fetch_current_user(conn, [])
  def call(conn, :require_authorized), do: require_authorized(conn, [])

  @doc "Assign `:current_user` from the session (nil when not logged in)."
  def fetch_current_user(conn, _opts) do
    user =
      case get_session(conn, :user_id) do
        nil -> nil
        id -> %{id: id, username: get_session(conn, :username)}
      end

    assign(conn, :current_user, user)
  end

  @doc "Redirect to the login page unless a user is assigned."
  def require_authorized(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> redirect(to: "/login")
      |> halt()
    end
  end

  @doc "Enforce auth on the connected LiveView mount, mirroring `require_authorized/2`."
  def on_mount(:ensure_authorized, _params, session, socket) do
    case session do
      %{"user_id" => id} when not is_nil(id) ->
        user = %{id: id, username: session["username"]}
        {:cont, Phoenix.Component.assign(socket, :current_user, user)}

      _ ->
        {:halt, Phoenix.LiveView.redirect(socket, to: "/login")}
    end
  end

  @doc "Generate an opaque, single-use state token for the OAuth redirect."
  @spec gen_state() :: String.t()
  def gen_state, do: 32 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

  @doc "Constant-time comparison of the expected vs. returned OAuth state."
  @spec valid_state?(term(), term()) :: boolean()
  def valid_state?(expected, got) when is_binary(expected) and is_binary(got),
    do: Plug.Crypto.secure_compare(expected, got)

  def valid_state?(_, _), do: false
end
