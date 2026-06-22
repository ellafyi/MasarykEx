defmodule MasarykEx.Commands.Hello.Definition do
  @moduledoc "Say hello."

  use MasarykEx.Core.Command

  alias MasarykEx.Core.Response

  @impl true
  def definition do
    %{name: "hello", description: "Say hello", args: []}
  end

  @impl true
  def run(_request) do
    Response.text("Hello from the other side")
  end
end
