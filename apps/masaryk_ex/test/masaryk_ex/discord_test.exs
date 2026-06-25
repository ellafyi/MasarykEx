defmodule MasarykEx.DiscordTest do
  use ExUnit.Case, async: false

  alias MasarykEx.Discord

  setup do
    prev_guild = Application.get_env(:masaryk_ex, :discord_guild_id)
    prev_role = Application.get_env(:masaryk_ex, :stats_role_id)

    Application.put_env(:masaryk_ex, :discord_guild_id, 111)
    Application.put_env(:masaryk_ex, :stats_role_id, 999)

    on_exit(fn ->
      restore(:discord_guild_id, prev_guild)
      restore(:stats_role_id, prev_role)
      Application.delete_env(:masaryk_ex, :discord_member_fetcher)
    end)

    :ok
  end

  defp restore(key, nil), do: Application.delete_env(:masaryk_ex, key)
  defp restore(key, val), do: Application.put_env(:masaryk_ex, key, val)

  defp stub_fetcher(fun), do: Application.put_env(:masaryk_ex, :discord_member_fetcher, fun)

  test "authorized when the user holds the configured role (int or string id)" do
    stub_fetcher(fn 111, 42 -> {:ok, %{roles: [1, 999, 7]}} end)
    assert Discord.stats_authorized?(42)
    assert Discord.stats_authorized?("42")
  end

  test "denied when the user lacks the role" do
    stub_fetcher(fn 111, 42 -> {:ok, %{roles: [1, 2]}} end)
    refute Discord.stats_authorized?(42)
  end

  test "fails closed when the member lookup errors (e.g. not in guild)" do
    stub_fetcher(fn 111, 42 -> {:error, :not_found} end)
    refute Discord.stats_authorized?(42)
  end

  test "denied when no role is configured" do
    Application.delete_env(:masaryk_ex, :stats_role_id)
    stub_fetcher(fn 111, 42 -> {:ok, %{roles: [999]}} end)
    refute Discord.stats_authorized?(42)
  end

  test "denied for a non-numeric user id" do
    refute Discord.stats_authorized?("not-a-number")
  end
end
