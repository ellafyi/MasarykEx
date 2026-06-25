defmodule MasarykExWeb.Router do
  use Phoenix.Router, helpers: false

  import Phoenix.LiveView.Router
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :put_root_layout, html: {MasarykExWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug MasarykExWeb.Auth, :fetch_current_user
  end

  pipeline :require_auth do
    plug MasarykExWeb.Auth, :require_authorized
  end

  scope "/", MasarykExWeb do
    pipe_through :browser

    get "/login", AuthController, :login
    get "/auth/discord", AuthController, :request
    get "/auth/discord/callback", AuthController, :callback
    get "/logout", AuthController, :logout
  end

  scope "/" do
    pipe_through [:browser, :require_auth]

    live_session :authenticated, on_mount: {MasarykExWeb.Auth, :ensure_authorized} do
      live "/stats", MasarykExWeb.Live.StatsLive
      live "/controls", MasarykExWeb.Live.ControlsLive
    end

    live_dashboard "/dashboard",
      metrics: MasarykExWeb.Telemetry,
      on_mount: [{MasarykExWeb.Auth, :ensure_authorized}]
  end
end
