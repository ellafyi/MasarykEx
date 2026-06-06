defmodule MasarykEx.Commands.Algo do
  @moduledoc "Say surprise."

  use MasarykEx.Core.Command

  alias MasarykEx.Core.Response

  @impl true
  def definition do
    %{name: "algo", description: "Trick for passing algo", args: []}
  end

  @impl true
  def run(_request) do
    Response.text("Test")
  end
end
