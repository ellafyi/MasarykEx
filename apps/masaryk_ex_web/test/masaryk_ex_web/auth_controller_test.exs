defmodule MasarykExWeb.AuthControllerTest do
  use MasarykExWeb.ConnCase

  alias MasarykEx.Discord.OAuth

  setup do
    on_exit(fn ->
      Application.delete_env(:masaryk_ex, :discord_oauth_fetcher)
      Application.delete_env(:masaryk_ex, :discord_member_fetcher)
      Application.delete_env(:masaryk_ex, :stats_role_id)
      Application.delete_env(:masaryk_ex, :discord_guild_id)
      Application.delete_env(:masaryk_ex, OAuth)
    end)

    :ok
  end

  defp stub_oauth_user(user),
    do: Application.put_env(:masaryk_ex, :discord_oauth_fetcher, fn _code -> {:ok, user} end)

  defp stub_member_roles(fun),
    do: Application.put_env(:masaryk_ex, :discord_member_fetcher, fun)

  defp configure_role(role_id, guild_id) do
    Application.put_env(:masaryk_ex, :stats_role_id, role_id)
    Application.put_env(:masaryk_ex, :discord_guild_id, guild_id)
  end

  describe "GET /auth/discord/callback" do
    test "rejects a mismatched OAuth state with 403", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{oauth_state: "expected"})
        |> get("/auth/discord/callback", %{"code" => "x", "state" => "wrong"})

      assert conn.status == 403
      assert get_session(conn, :user_id) == nil
    end

    test "denies a user who lacks the required role", %{conn: conn} do
      stub_oauth_user(%{id: "42", username: "nope"})
      stub_member_roles(fn 111, 42 -> {:ok, %{roles: [1, 2]}} end)
      configure_role(999, 111)

      conn =
        conn
        |> init_test_session(%{oauth_state: "s"})
        |> get("/auth/discord/callback", %{"code" => "c", "state" => "s"})

      assert conn.status == 403
      assert html_response(conn, 403) =~ "Access denied"
      assert get_session(conn, :user_id) == nil
    end

    test "authorizes a user with the role and stores the session", %{conn: conn} do
      stub_oauth_user(%{id: "42", username: "ok"})
      stub_member_roles(fn 111, 42 -> {:ok, %{roles: [999]}} end)
      configure_role(999, 111)

      conn =
        conn
        |> init_test_session(%{oauth_state: "s"})
        |> get("/auth/discord/callback", %{"code" => "c", "state" => "s"})

      assert redirected_to(conn) == "/stats"
      assert get_session(conn, :user_id) == "42"
      assert get_session(conn, :oauth_state) == nil
    end
  end

  test "GET /login renders the sign-in page", %{conn: conn} do
    conn = get(conn, "/login")
    assert html_response(conn, 200) =~ "Sign in with Discord"
  end

  test "GET /auth/discord redirects to Discord and sets a state", %{conn: conn} do
    Application.put_env(:masaryk_ex, OAuth,
      client_id: "cid",
      redirect_uri: "https://example.test/cb"
    )

    conn = get(conn, "/auth/discord")

    assert redirected_to(conn, 302) =~ "https://discord.com/api/oauth2/authorize"
    assert get_session(conn, :oauth_state)
  end

  test "GET /logout clears the session", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{user_id: "42", username: "ok"})
      |> get("/logout")

    assert redirected_to(conn) == "/login"
    assert get_session(conn, :user_id) == nil
  end
end
