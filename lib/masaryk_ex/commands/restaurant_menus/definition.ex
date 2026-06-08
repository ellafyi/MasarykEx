defmodule MasarykEx.Commands.RestaurantMenus.Definition do
  @moduledoc "List available restaurant menus."

  use MasarykEx.Core.Command

  alias MasarykEx.Config
  alias MasarykEx.Core.{Request, Response}

  @impl true
  def definition do
    %{name: "restaurant-menus", description: "List available restaurant menus", args: []}
  end

  @impl true
  def config_schema do
    %{enabled: true, restaurants: ["Padagali", "U Drevaka"]}
  end

  @impl true
  def run(%Request{context: context}) do
    Config.get(__MODULE__, :restaurants, context)
    |> format_menus()
    |> Response.text()
  end

  defp format_menus([]), do: "No menus available right now."

  defp format_menus(menus) do
    "Today's options:\n" <> Enum.map_join(menus, "\n", &"- #{&1}")
  end
end
