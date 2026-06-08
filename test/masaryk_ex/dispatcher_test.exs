defmodule MasarykEx.Commands.Ping.Definition do
  @moduledoc false
  use MasarykEx.Core.Command

  alias MasarykEx.Core.Response

  @impl true
  def definition, do: %{name: "ping", description: "ping", args: []}

  @impl true
  def run(_request), do: Response.text("pong")
end

defmodule MasarykEx.DispatcherTest do
  use ExUnit.Case, async: false

  alias MasarykEx.Core.{Context, Dispatcher, Request, Response}

  defp request(command), do: %Request{command: command, context: %Context{interface: :cli}}

  test "runs a known, enabled command" do
    assert %Response{content: "pong"} = Dispatcher.run(request("ping"))
  end

  test "reports unknown commands" do
    assert %Response{content: "Unknown command: nope" <> _} = Dispatcher.run(request("nope"))
  end

  test "refuses a disabled command" do
    Application.put_env(:masaryk_ex, MasarykEx.Commands.Ping.Definition, enabled: false)
    on_exit(fn -> Application.delete_env(:masaryk_ex, MasarykEx.Commands.Ping.Definition) end)

    assert %Response{content: "The `ping` command is currently disabled."} =
             Dispatcher.run(request("ping"))
  end
end
