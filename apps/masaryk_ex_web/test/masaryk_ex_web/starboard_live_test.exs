defmodule MasarykExWeb.StarboardLiveTest do
  use MasarykExWeb.ConnCase

  alias MasarykEx.Data.Starboard.{Starboards, StarredMessages}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MasarykEx.Repo)
    # The connected LiveView runs in its own process; share the connection.
    Ecto.Adapters.SQL.Sandbox.mode(MasarykEx.Repo, {:shared, self()})

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

  defp authed(conn), do: init_test_session(conn, %{user_id: "42", username: "ok"})

  defp create_board(overrides) do
    {:ok, board} =
      Starboards.create(
        Map.merge(%{guild_id: "9", name: "Board", target_channel_id: "900"}, overrides)
      )

    board
  end

  test "redirects to /login when not authenticated", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/login"}}} = live(conn, "/starboard")
  end

  test "renders the page and lists configured boards", %{conn: conn} do
    create_board(%{name: "Memes", target_channel_id: "900", include_channel_ids: ["111"]})

    {:ok, _view, html} = live(authed(conn), "/starboard")

    assert html =~ "Starboard"
    assert html =~ "Log out"
    assert html =~ "New board"
    assert html =~ "Memes"
  end

  test "creates a board via the form", %{conn: conn} do
    {:ok, view, _html} = live(authed(conn), "/starboard")

    view
    |> form("#starboard-form", %{
      "name" => "Memes",
      "target_channel_id" => "900",
      "include_channel_ids" => "111, 222",
      "exclude_channel_ids" => "",
      "threshold" => "3",
      "thread_threshold" => "4",
      "position" => "0"
    })
    |> render_submit()

    assert [board] = Starboards.for_guild("9")
    assert board.name == "Memes"
    assert board.guild_id == "9"
    assert board.include_channel_ids == ["111", "222"]
    assert board.threshold == 3
    assert board.thread_threshold == 4
    assert board.enabled == true

    assert render(view) =~ "Memes"
  end

  test "editing a board updates it", %{conn: conn} do
    board = create_board(%{name: "Old", target_channel_id: "900"})

    {:ok, view, _html} = live(authed(conn), "/starboard")

    view |> element("button[phx-value-id='#{board.id}']", "Edit") |> render_click()
    view |> form("#starboard-form", %{"name" => "Renamed"}) |> render_submit()

    assert Starboards.get(board.id).name == "Renamed"
    assert render(view) =~ "Renamed"
  end

  test "deleting a board removes it", %{conn: conn} do
    board = create_board(%{name: "Doomed", target_channel_id: "900"})

    {:ok, view, html} = live(authed(conn), "/starboard")
    assert html =~ "Doomed"

    view |> element("button[phx-value-id='#{board.id}']", "Delete") |> render_click()

    assert Starboards.get(board.id) == nil
    refute render(view) =~ "Doomed"
  end

  test "the starred table filters by board", %{conn: conn} do
    alpha = create_board(%{name: "Alpha", target_channel_id: "900"})
    beta = create_board(%{name: "Beta", target_channel_id: "901"})

    {:ok, _} =
      StarredMessages.create(%{
        message_id: "ma",
        emoji: "⭐",
        author: "alice_a",
        starboard_id: alpha.id
      })

    {:ok, _} =
      StarredMessages.create(%{
        message_id: "mb",
        emoji: "⭐",
        author: "bob_b",
        starboard_id: beta.id
      })

    {:ok, view, html} = live(authed(conn), "/starboard")
    assert html =~ "alice_a"
    assert html =~ "bob_b"

    filtered =
      view
      |> form("form[phx-change='filter_board']", %{"starboard_id" => to_string(alpha.id)})
      |> render_change()

    assert filtered =~ "alice_a"
    refute filtered =~ "bob_b"
  end
end
