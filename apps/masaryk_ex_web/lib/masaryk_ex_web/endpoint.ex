defmodule MasarykExWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :masaryk_ex_web

  socket "/live", Phoenix.LiveView.Socket, websocket: true, longpoll: false

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  plug Plug.Parsers, parsers: [:urlencoded, :multipart, :json], json_decoder: Jason
  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session,
    store: :cookie,
    key: "_masaryk_ex_web_key",
    signing_salt: "dashboard"
  plug MasarykExWeb.Router
end
