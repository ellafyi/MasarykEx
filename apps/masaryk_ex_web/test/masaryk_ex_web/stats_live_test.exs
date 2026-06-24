defmodule MasarykExWeb.StatsLiveTest do
  use MasarykExWeb.ConnCase

  test "redirects to /login when not authenticated", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/login"}}} = live(conn, "/stats")
  end

  test "renders the stats page for an authenticated user", %{conn: conn} do
    conn = init_test_session(conn, %{user_id: "42", username: "ok"})
    {:ok, _view, html} = live(conn, "/stats")
    assert html =~ "Bot Stats"
    assert html =~ "Log out"
    assert html =~ "ok"
  end
end
