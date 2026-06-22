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
  end

  scope "/" do
    pipe_through :browser
    live "/stats", MasarykExWeb.Live.StatsLive
    live_dashboard "/dashboard", metrics: MasarykExWeb.Telemetry
  end
end
