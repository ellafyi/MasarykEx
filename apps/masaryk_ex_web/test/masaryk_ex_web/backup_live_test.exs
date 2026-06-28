defmodule MasarykExWeb.BackupLiveTest do
  use MasarykExWeb.ConnCase

  alias MasarykEx.Config.Store
  alias MasarykEx.Data.Backups.BackedUpMessages
  alias MasarykEx.Services.MessageBackup.Definition

  @feature inspect(Definition)

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MasarykEx.Repo)
    # The connected LiveView and the Config.Store run in other processes.
    Ecto.Adapters.SQL.Sandbox.mode(MasarykEx.Repo, {:shared, self()})
    :ok
  end

  defp authed(conn), do: init_test_session(conn, %{user_id: "42", username: "ok"})

  test "redirects to /login when not authenticated", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/login"}}} = live(conn, "/backup")
  end

  test "renders progress, settings, and search for an authenticated user", %{conn: conn} do
    {:ok, _view, html} = live(authed(conn), "/backup")

    assert html =~ "Message Backup"
    assert html =~ "Log out"
    assert html =~ "messages archived"
    assert html =~ "Activity-log channel"
    assert html =~ "Search archived messages"
    # idle by default → the toggle offers to Start
    assert html =~ ~s(phx-click="toggle")
    assert html =~ "Start"
  end

  test "default render lists no archived rows and shows an empty-state hint", %{conn: conn} do
    BackedUpMessages.upsert(%{
      message_id: "secret",
      channel_id: "c1",
      author_id: "u1",
      content: "DISTINCTIVE_NEEDLE_TEXT",
      posted_at: ~U[2026-01-01 00:00:00Z]
    })

    {:ok, _view, html} = live(authed(conn), "/backup")

    refute html =~ "DISTINCTIVE_NEEDLE_TEXT"
    assert html =~ "Search the archive to list messages."
  end

  test "a progress broadcast refreshes status without listing archived rows", %{conn: conn} do
    BackedUpMessages.upsert(%{
      message_id: "secret2",
      channel_id: "c1",
      author_id: "u1",
      content: "PROGRESS_NEEDLE_TEXT",
      posted_at: ~U[2026-01-01 00:00:00Z]
    })

    {:ok, view, _html} = live(authed(conn), "/backup")

    send(view.pid, {:backup, :progress})
    html = render(view)

    refute html =~ "PROGRESS_NEEDLE_TEXT"
    assert html =~ "messages archived"
  end

  test "saving the log channel persists it through the config store", %{conn: conn} do
    {:ok, view, _html} = live(authed(conn), "/backup")

    view
    |> form("#backup-settings", %{channel_id: "12345"})
    |> render_submit()

    assert {:ok, "12345"} == Store.get(@feature, "channel_id", "global")
  end

  test "search filters archived messages and paginates", %{conn: conn} do
    base = ~U[2026-01-01 00:00:00Z]

    for n <- 1..30 do
      BackedUpMessages.upsert(%{
        message_id: "m#{n}",
        channel_id: "c1",
        author_id: "u#{n}",
        author_username: "user#{n}",
        content: "alpha message #{n}",
        posted_at: DateTime.add(base, n, :hour)
      })
    end

    BackedUpMessages.upsert(%{message_id: "other", content: "beta", posted_at: base})

    {:ok, view, _html} = live(authed(conn), "/backup")

    html = view |> form("#backup-search", %{query: "alpha"}) |> render_submit()
    assert html =~ "30 matches"
    assert html =~ "Page 1 of 2"

    html = view |> element("button", "Next") |> render_click()
    assert html =~ "Page 2 of 2"
  end
end
