defmodule MasarykExWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :masaryk_ex_web

  # Shared by Plug.Session (HTTP) and the LiveView socket (WebSocket) so the
  # session cookie is available in connected mounts, not just HTTP requests.
  @session_options [
    store: :cookie,
    key: "_masaryk_ex_web_key",
    signing_salt: "dashboard",
    same_site: "Lax",
    max_age: 60 * 60 * 8
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: false

  plug :health_check

  # Liveness probe for the Kamal proxy; answered before session/router work.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.Static, at: "/assets/phoenix", from: {:phoenix, "priv/static"}
  plug Plug.Static, at: "/assets/lv", from: {:phoenix_live_view, "priv/static"}

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  plug Plug.Parsers, parsers: [:urlencoded, :multipart, :json], json_decoder: Jason
  plug Plug.MethodOverride
  plug Plug.Head

  plug Plug.Session, @session_options

  plug MasarykExWeb.Router

  defp health_check(%Plug.Conn{request_path: "/up"} = conn, _opts) do
    conn |> Plug.Conn.send_resp(200, "OK") |> Plug.Conn.halt()
  end

  defp health_check(conn, _opts), do: conn
end
