defmodule MasarykExWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :masaryk_ex_web

  socket "/live", Phoenix.LiveView.Socket, websocket: true, longpoll: false

  plug Plug.Static, at: "/assets/phoenix", from: {:phoenix, "priv/static"}
  plug Plug.Static, at: "/assets/lv", from: {:phoenix_live_view, "priv/static"}

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  plug Plug.Parsers, parsers: [:urlencoded, :multipart, :json], json_decoder: Jason
  plug Plug.MethodOverride
  plug Plug.Head

  plug Plug.Session,
    store: :cookie,
    key: "_masaryk_ex_web_key",
    signing_salt: "dashboard",
    same_site: "Lax",
    max_age: 60 * 60 * 8

  plug MasarykExWeb.Router
end
