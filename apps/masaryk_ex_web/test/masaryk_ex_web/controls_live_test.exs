defmodule MasarykExWeb.ControlsLiveTest do
  use MasarykExWeb.ConnCase

  test "redirects to /login when not authenticated", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/login"}}} = live(conn, "/controls")
  end

  test "renders the command list with toggle controls for an authenticated user", %{conn: conn} do
    conn = init_test_session(conn, %{user_id: "42", username: "ok"})
    {:ok, _view, html} = live(conn, "/controls")

    assert html =~ "Command Controls"
    assert html =~ "phx-click=\"toggle\""
    assert html =~ "config"
  end
end
