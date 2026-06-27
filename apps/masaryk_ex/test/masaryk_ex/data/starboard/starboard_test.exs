defmodule MasarykEx.Data.Starboard.StarboardTest do
  use ExUnit.Case, async: false

  alias MasarykEx.Data.Starboard.{Starboard, Starboards}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MasarykEx.Repo)
  end

  defp attrs(overrides \\ %{}) do
    Map.merge(%{guild_id: "9", name: "Memes", target_channel_id: "900"}, overrides)
  end

  test "changeset requires guild_id, name and target_channel_id" do
    changeset = Starboard.changeset(%Starboard{}, %{})

    refute changeset.valid?
    assert "can't be blank" in errors_on(changeset, :guild_id)
    assert "can't be blank" in errors_on(changeset, :name)
    assert "can't be blank" in errors_on(changeset, :target_channel_id)
  end

  test "changeset rejects non-positive thresholds" do
    changeset = Starboard.changeset(%Starboard{}, attrs(%{threshold: 0, thread_threshold: -1}))

    assert "must be greater than 0" in errors_on(changeset, :threshold)
    assert "must be greater than 0" in errors_on(changeset, :thread_threshold)
  end

  test "changeset normalizes id lists: trims, drops non-digits, dedupes, keeps order" do
    changeset =
      Starboard.changeset(
        %Starboard{},
        attrs(%{
          include_channel_ids: ["111", "", "  222 ", "111", "<#333>", "abc"],
          exclude_channel_ids: ["444", "444"]
        })
      )

    assert changeset.valid?
    assert Ecto.Changeset.get_change(changeset, :include_channel_ids) == ["111", "222"]
    assert Ecto.Changeset.get_change(changeset, :exclude_channel_ids) == ["444"]
  end

  test "create/get/update/delete round-trip" do
    assert {:ok, board} = Starboards.create(attrs())
    assert Starboards.get(board.id).name == "Memes"

    assert {:ok, updated} = Starboards.update(board, %{name: "Renamed"})
    assert updated.name == "Renamed"

    assert {:ok, _} = Starboards.delete(updated)
    assert Starboards.get(board.id) == nil
  end

  test "for_guild/1 scopes by guild and orders by position then id" do
    {:ok, _} = Starboards.create(attrs(%{name: "B", position: 1}))
    {:ok, _} = Starboards.create(attrs(%{name: "A", position: 0}))
    {:ok, _} = Starboards.create(attrs(%{guild_id: "other", name: "X", position: 0}))

    assert Starboards.for_guild("9") |> Enum.map(& &1.name) == ["A", "B"]
    assert Starboards.for_guild("nope") == []
    assert Starboards.for_guild(nil) == []
  end

  test "name is unique per guild" do
    assert {:ok, _} = Starboards.create(attrs())
    assert {:error, changeset} = Starboards.create(attrs())

    assert Enum.any?(changeset.errors, fn {_field, {msg, _opts}} ->
             msg == "has already been taken"
           end)
  end

  defp errors_on(changeset, field) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Map.get(field, [])
  end
end
