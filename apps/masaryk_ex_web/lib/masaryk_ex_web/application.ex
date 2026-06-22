defmodule MasarykExWeb.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: MasarykExWeb.PubSub},
      MasarykExWeb.Telemetry,
      MasarykExWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: MasarykExWeb.Supervisor)
  end
end
