defmodule MasarykEx.CommandTest do
  use ExUnit.Case, async: true

  alias MasarykEx.Core.Command

  test "to_module/1 joins kebab-case and targets the Definition module" do
    assert Command.to_module("hello") == MasarykEx.Commands.Hello.Definition
    assert Command.to_module("restaurant-menus") == MasarykEx.Commands.RestaurantMenus.Definition
  end
end
