defmodule MasarykEx.Discord.OAuth do
  @moduledoc """
  Discord OAuth2 authorization-code flow for the web dashboard, hand-rolled over
  `Req`.

  Only the `identify` scope is requested; the user's guild roles are read
  separately with the bot token (see `MasarykEx.Discord`). The client secret and
  access tokens are never logged.
  """

  require Logger

  @authorize_url "https://discord.com/api/oauth2/authorize"
  @token_url "https://discord.com/api/oauth2/token"
  @identify_url "https://discord.com/api/users/@me"

  @doc """
  Build the Discord authorization URL to redirect the user to. `state` is an
  opaque CSRF token the caller stores in the session and re-checks on callback.
  """
  @spec authorize_url(String.t()) :: String.t()
  def authorize_url(state) do
    query =
      URI.encode_query(
        response_type: "code",
        client_id: config(:client_id),
        redirect_uri: config(:redirect_uri),
        scope: "identify",
        state: state,
        prompt: "none"
      )

    @authorize_url <> "?" <> query
  end

  @doc """
  Exchange an authorization `code` for the identified user.

  Returns `{:ok, %{id: String.t(), username: String.t()}}` or `{:error, reason}`.
  """
  @spec fetch_user(String.t()) ::
          {:ok, %{id: String.t(), username: String.t()}} | {:error, term()}
  def fetch_user(code) do
    case Application.get_env(:masaryk_ex, :discord_oauth_fetcher) do
      nil -> do_fetch_user(code)
      fun when is_function(fun, 1) -> fun.(code)
    end
  end

  defp do_fetch_user(code) do
    with {:ok, token} <- exchange_code(code) do
      identify(token)
    end
  end

  defp exchange_code(code) do
    form = [
      grant_type: "authorization_code",
      code: code,
      redirect_uri: config(:redirect_uri),
      client_id: config(:client_id),
      client_secret: config(:client_secret)
    ]

    case Req.post(@token_url, form: form) do
      {:ok, %{status: 200, body: %{"access_token" => token}}} ->
        {:ok, token}

      {:ok, %{status: status}} ->
        Logger.warning("Discord token exchange failed: HTTP #{status}")
        {:error, :token_exchange_failed}

      {:error, reason} ->
        Logger.warning("Discord token exchange error: #{inspect(reason)}")
        {:error, :token_exchange_failed}
    end
  end

  defp identify(token) do
    case Req.get(@identify_url, auth: {:bearer, token}) do
      {:ok, %{status: 200, body: %{"id" => id, "username" => username}}} ->
        {:ok, %{id: id, username: username}}

      {:ok, %{status: status}} ->
        Logger.warning("Discord identify failed: HTTP #{status}")
        {:error, :identify_failed}

      {:error, reason} ->
        Logger.warning("Discord identify error: #{inspect(reason)}")
        {:error, :identify_failed}
    end
  end

  defp config(key) do
    Application.get_env(:masaryk_ex, __MODULE__, []) |> Keyword.get(key)
  end
end
