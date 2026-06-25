defmodule MasarykExWeb.AuthHTML do
  @moduledoc """
  Standalone HTML pages for the auth flow (login, access-denied). Rendered
  without the live root layout so the LiveView socket script isn't pulled onto
  these non-live pages.
  """

  use Phoenix.Component

  def login(assigns) do
    ~H"""
    <.shell>
      <h1>MasarykEx Dashboard</h1>
      <p>Sign in with Discord to view the bot stats.</p>
      <a class="btn" href="/auth/discord">Sign in with Discord</a>
    </.shell>
    """
  end

  def forbidden(assigns) do
    ~H"""
    <.shell>
      <h1>Access denied</h1>
      <p>Your Discord account doesn't have the role required to view this dashboard.</p>
      <a class="btn" href="/login">Back to sign in</a>
    </.shell>
    """
  end

  slot :inner_block, required: true

  defp shell(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>MasarykEx Dashboard</title>
        <style>
          body { font-family: sans-serif; max-width: 480px; margin: 80px auto; padding: 0 16px; text-align: center; }
          h1 { font-size: 1.5rem; }
          p { color: #555; }
          .btn { display: inline-block; margin-top: 16px; padding: 10px 20px; background: #5865F2; color: #fff; border-radius: 6px; text-decoration: none; font-weight: bold; }
        </style>
      </head>
      <body>
        <%= render_slot(@inner_block) %>
      </body>
    </html>
    """
  end
end
