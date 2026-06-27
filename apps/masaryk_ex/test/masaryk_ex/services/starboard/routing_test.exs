defmodule MasarykEx.Services.Starboard.RoutingTest do
  use ExUnit.Case, async: true

  alias MasarykEx.Data.Starboard.Starboard
  alias MasarykEx.Services.Starboard.Routing

  defp board(attrs), do: struct(Starboard, attrs)

  test "an explicit include beats an empty-include catch-all" do
    memes = board(id: 1, position: 0, include_channel_ids: ["100"], target_channel_id: "900")
    general = board(id: 2, position: 1, include_channel_ids: [], target_channel_id: "901")

    assert Routing.select([general, memes], "100").id == memes.id
  end

  test "an exclude removes the channel even from a catch-all" do
    general =
      board(
        id: 1,
        include_channel_ids: [],
        exclude_channel_ids: ["100"],
        target_channel_id: "900"
      )

    assert Routing.select([general], "100") == nil
    assert Routing.select([general], "200").id == general.id
  end

  test "an empty-include catch-all matches when no explicit board claims the channel" do
    general = board(id: 1, include_channel_ids: [], target_channel_id: "900")
    memes = board(id: 2, include_channel_ids: ["555"], target_channel_id: "901")

    assert Routing.select([general, memes], "100").id == general.id
  end

  test "ties break by position then id" do
    a = board(id: 5, position: 1, include_channel_ids: [], target_channel_id: "900")
    b = board(id: 3, position: 1, include_channel_ids: [], target_channel_id: "901")
    c = board(id: 9, position: 0, include_channel_ids: [], target_channel_id: "902")

    # Lowest position wins.
    assert Routing.select([a, b, c], "100").id == c.id
    # Among equal positions, the lowest id wins.
    assert Routing.select([a, b], "100").id == b.id
  end

  test "returns nil when no board is eligible" do
    memes = board(id: 1, include_channel_ids: ["555"], target_channel_id: "900")

    assert Routing.select([memes], "100") == nil
    assert Routing.select([], "100") == nil
  end

  test "target_channel?/2 detects a board's own target channel" do
    general = board(id: 1, include_channel_ids: [], target_channel_id: "900")

    assert Routing.target_channel?([general], "900")
    refute Routing.target_channel?([general], "100")
  end
end
