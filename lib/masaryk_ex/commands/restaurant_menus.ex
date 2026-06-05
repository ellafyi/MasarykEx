defmodule MasarykEx.Commands.RestaurantMenus do
  @moduledoc "List available restaurant menus."

  use MasarykEx.Command

  @impl true
  def definition do
    %{
      name: "restaurant-menus",
      description: "List available restaurant menus"
    }
  end

  @impl true
  def handle(_interaction) do
    menus = fetch_menus()

    %{
      type: 4,
      data: %{
        content: format_menus(menus)
      }
    }
  end

  # --- Domain logic, separated from Discord plumbing ---

  defp fetch_menus do
    # Replace with real data source (DB, API, etc.)
    ["Café Mírná", "Bistro Pod Lípou", "Pizzeria Verona"]
  end

  defp format_menus([]), do: "No menus available right now."

  defp format_menus(menus) do
    header = "Today's options:"
    items = Enum.map_join(menus, "\n", &"- #{&1}")
    "#{header}\n#{items}"
  end
end
