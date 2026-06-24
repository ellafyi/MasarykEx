defmodule MasarykEx.Discord do
  @moduledoc """
  Read-side helpers over the bot's Discord connection, used by the web dashboard
  to authorize users by their guild roles.

  Everything here **fails closed**: any missing config, lookup error, or user not
  in the guild results in denial rather than access. Roles are read with the bot
  token (the bot is already in the guild), so the OAuth flow only needs the
  `identify` scope.
  """

  @doc """
  Role IDs the given user currently has in the configured guild.

  Returns `{:ok, [role_id]}` or `:error` if the guild isn't configured or the
  member can't be fetched (e.g. the user isn't in the guild, or Discord is off).
  """
  @spec member_roles(integer()) :: {:ok, [integer()]} | :error
  def member_roles(user_id) when is_integer(user_id) do
    with guild_id when is_integer(guild_id) <- guild_id(),
         {:ok, %{roles: roles}} <- fetcher().(guild_id, user_id) do
      {:ok, roles}
    else
      _ -> :error
    end
  end

  @doc """
  Whether the user may view the dashboard: true only if they hold the configured
  `:stats_role_id` in the guild. Accepts the user ID as an integer or string.
  """
  @spec stats_authorized?(integer() | String.t()) :: boolean()
  def stats_authorized?(user_id) when is_binary(user_id) do
    case Integer.parse(user_id) do
      {id, ""} -> stats_authorized?(id)
      _ -> false
    end
  end

  def stats_authorized?(user_id) when is_integer(user_id) do
    with role_id when is_integer(role_id) <- stats_role_id(),
         {:ok, roles} <- member_roles(user_id) do
      role_id in roles
    else
      _ -> false
    end
  end

  defp guild_id, do: Application.get_env(:masaryk_ex, :discord_guild_id)
  defp stats_role_id, do: Application.get_env(:masaryk_ex, :stats_role_id)

  defp fetcher do
    Application.get_env(:masaryk_ex, :discord_member_fetcher, &Nostrum.Api.Guild.member/2)
  end
end
