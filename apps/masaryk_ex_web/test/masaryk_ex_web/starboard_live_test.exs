defmodule MasarykExWeb.StarboardLiveTest do
  use MasarykExWeb.ConnCase

  alias MasarykEx.Config.Store
  alias MasarykEx.Data.Starboard.StarredMessages
  alias MasarykEx.Services.Starboard.Definition

  @feature inspect(Definition)

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MasarykEx.Repo)
    # The connected LiveView runs in its own process; share the connection.
    Ecto.Adapters.SQL.Sandbox.mode(MasarykEx.Repo, {:shared, self()})
    :ok
  end

  defp authed(conn), do: init_test_session(conn, %{user_id: "42", username: "ok"})

  test "redirects to /login when not authenticated", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/login"}}} = live(conn, "/starboard")
  end

  test "renders settings and an empty state for an authenticated user", %{conn: conn} do
    {:ok, _view, html} = live(authed(conn), "/starboard")

    assert html =~ "Starboard"
    assert html =~ "Log out"
    assert html =~ "Reaction threshold"
    assert html =~ "No starred messages yet."
  end

  test "saving settings persists them through the config store", %{conn: conn} do
    {:ok, view, _html} = live(authed(conn), "/starboard")

    view
    |> form("form", %{threshold: "5", channel_id: "12345"})
    |> render_submit()

    assert {:ok, 5} == Store.get(@feature, "threshold", "global")
    assert {:ok, "12345"} == Store.get(@feature, "channel_id", "global")
  end

  test "shows a direct link to a starred message's media", %{conn: conn} do
    {:ok, _} =
      StarredMessages.create(%{
        message_id: "m1",
        emoji: "⭐",
        reaction_count: 4,
        media_url: "https://cdn/cat.png",
        media_type: "image"
      })

    {:ok, _view, html} = live(authed(conn), "/starboard")
    assert html =~ "https://cdn/cat.png"
    assert html =~ "View image"
  end

  test "lists starred messages with pagination", %{conn: conn} do
    for n <- 1..25 do
      {:ok, _} =
        StarredMessages.create(%{
          message_id: "m#{n}",
          emoji: "⭐",
          reaction_count: n,
          author: "u#{n}"
        })
    end

    {:ok, view, html} = live(authed(conn), "/starboard")
    assert html =~ "Page 1 of 2"
    assert html =~ "u25"

    html = view |> element("button", "Next") |> render_click()
    assert html =~ "Page 2 of 2"
    # "u5" is unique to page 2's authors (u5..u1); page 1 holds u6..u25.
    assert html =~ "u5"
  end
end
