defmodule MasarykEx.Commands.Hello do
  @moduledoc "Simple hello slash command."

  use MasarykEx.Command

  @impl true
  def definition do
    %{
      name: "hello",
      description: "Say hello with a slash command"
    }
  end

  @impl true
  def handle(_interaction) do
    %{
      type: 4,
      data: %{
        content: "Hello from the other side"
      }
    }
  end
end
