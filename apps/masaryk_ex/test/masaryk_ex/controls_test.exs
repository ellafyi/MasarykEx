defmodule MasarykEx.ControlsTest do
  use ExUnit.Case, async: false

  alias MasarykEx.Controls

  test "list_commands/0 returns commands, enabled by default" do
    commands = Controls.list_commands()

    assert commands != []
    assert Enum.all?(commands, &is_binary(&1.name))
    assert Enum.all?(commands, &is_atom(&1.module))
    assert Enum.all?(commands, & &1.enabled)
  end

  test "a static enabled:false override is reflected in the listing" do
    [%{module: module, name: name} | _] = Controls.list_commands()

    Application.put_env(:masaryk_ex, module, enabled: false)
    on_exit(fn -> Application.delete_env(:masaryk_ex, module) end)

    cmd = Enum.find(Controls.list_commands(), &(&1.name == name))
    refute cmd.enabled
  end
end
