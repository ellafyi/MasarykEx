defmodule MasarykEx.StarboardTest do
  use ExUnit.Case, async: false

  alias MasarykEx.Starboard
  alias MasarykEx.Data.Starboard.StarredMessages

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MasarykEx.Repo)

    prev = Application.get_env(:masaryk_ex, :discord_guild_id)
    Application.put_env(:masaryk_ex, :discord_guild_id, 9)

    on_exit(fn ->
      case prev do
        nil -> Application.delete_env(:masaryk_ex, :discord_guild_id)
        val -> Application.put_env(:masaryk_ex, :discord_guild_id, val)
      end
    end)

    :ok
  end

  test "create_starboard/1 injects the configured guild and broadcasts {:starboard, :config}" do
    Phoenix.PubSub.subscribe(MasarykEx.PubSub, Starboard.topic())

    assert {:ok, board} = Starboard.create_starboard(%{name: "Memes", target_channel_id: "900"})
    assert board.guild_id == "9"
    assert_receive {:starboard, :config}
  end

  test "list_starboards/0 returns boards for the configured guild" do
    {:ok, _} = Starboard.create_starboard(%{name: "A", target_channel_id: "900"})

    assert [%{name: "A"}] = Starboard.list_starboards()
  end

  test "update_starboard/2 and delete_starboard/1 persist and broadcast" do
    {:ok, board} = Starboard.create_starboard(%{name: "A", target_channel_id: "900"})
    Phoenix.PubSub.subscribe(MasarykEx.PubSub, Starboard.topic())

    assert {:ok, updated} = Starboard.update_starboard(board, %{name: "B"})
    assert updated.name == "B"
    assert_receive {:starboard, :config}

    assert {:ok, _} = Starboard.delete_starboard(updated)
    assert_receive {:starboard, :config}
    assert Starboard.list_starboards() == []
  end

  test "an invalid create returns an error changeset and does not broadcast" do
    Phoenix.PubSub.subscribe(MasarykEx.PubSub, Starboard.topic())

    assert {:error, %Ecto.Changeset{}} =
             Starboard.create_starboard(%{name: "", target_channel_id: ""})

    refute_receive {:starboard, :config}, 50
  end

  test "list/1 and count/1 filter by :starboard_id" do
    {:ok, a} = Starboard.create_starboard(%{name: "A", target_channel_id: "900"})
    {:ok, b} = Starboard.create_starboard(%{name: "B", target_channel_id: "901"})

    {:ok, _} = StarredMessages.create(%{message_id: "m1", emoji: "⭐", starboard_id: a.id})
    {:ok, _} = StarredMessages.create(%{message_id: "m2", emoji: "⭐", starboard_id: b.id})
    {:ok, _} = StarredMessages.create(%{message_id: "m3", emoji: "⭐", starboard_id: a.id})

    assert Starboard.count() == 3
    assert Starboard.count(starboard_id: a.id) == 2

    ids = Starboard.list(starboard_id: a.id) |> Enum.map(& &1.message_id) |> Enum.sort()
    assert ids == ["m1", "m3"]
  end
end
