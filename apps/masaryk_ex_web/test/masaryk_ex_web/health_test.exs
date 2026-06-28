defmodule MasarykExWeb.HealthTest do
  use MasarykExWeb.ConnCase

  test "GET /up returns 200 for the proxy health check", %{conn: conn} do
    conn = get(conn, "/up")
    assert response(conn, 200) == "OK"
  end
end
