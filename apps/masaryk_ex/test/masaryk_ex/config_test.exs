defmodule MasarykEx.ConfigTest do
  use ExUnit.Case, async: false

  alias MasarykEx.Config
  alias MasarykEx.Core.Context

  defmodule Feature do
    def config_schema, do: %{enabled: true, greeting: "hi", max: 5}
  end

  @ctx %Context{interface: :cli}

  test "falls back to the schema default" do
    assert Config.get(Feature, :greeting, @ctx) == "hi"
    assert Config.get(Feature, :max, @ctx) == 5
  end

  test "enabled defaults to true even without a schema entry" do
    assert Config.get(MasarykEx.ConfigTest.NoSuchFeature, :enabled, @ctx) == true
  end

  test "config.exs / app env beats the schema default" do
    Application.put_env(:masaryk_ex, Feature, greeting: "yo")
    on_exit(fn -> Application.delete_env(:masaryk_ex, Feature) end)

    assert Config.get(Feature, :greeting, @ctx) == "yo"
    # keys not overridden still come from the schema
    assert Config.get(Feature, :max, @ctx) == 5
  end

  test "all/2 merges every layer into one map" do
    Application.put_env(:masaryk_ex, Feature, greeting: "yo")
    on_exit(fn -> Application.delete_env(:masaryk_ex, Feature) end)

    assert %{enabled: true, greeting: "yo", max: 5} = Config.all(Feature, @ctx)
  end
end
