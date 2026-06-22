defmodule MasarykExTest do
  use ExUnit.Case
  doctest MasarykEx

  test "greets the world" do
    assert MasarykEx.hello() == :world
  end
end
