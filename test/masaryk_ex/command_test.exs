defmodule MasarykEx.CommandTest do
  use ExUnit.Case, async: true

  alias MasarykEx.Core.Command

  test "to_module/1 joins kebab-case into a single module segment" do
    assert Command.to_module("hello") == MasarykEx.Commands.Hello
    assert Command.to_module("restaurant-menus") == MasarykEx.Commands.RestaurantMenus
  end
end
