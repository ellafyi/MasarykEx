defmodule MasarykExWeb.Router do
  use Phoenix.Router, helpers: false

  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/" do
    pipe_through :browser
    live_dashboard "/dashboard", metrics: MasarykExWeb.Telemetry
  end
end
