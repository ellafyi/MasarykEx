defmodule MasarykExWeb.Application do
  use Application

  def start(_type, _args) do
    children = [
      MasarykExWeb.Telemetry,
      MasarykExWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: MasarykExWeb.Supervisor)
  end
end
