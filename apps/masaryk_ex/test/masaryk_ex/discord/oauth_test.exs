defmodule MasarykEx.Discord.OAuthTest do
  use ExUnit.Case, async: false

  alias MasarykEx.Discord.OAuth

  setup do
    Application.put_env(:masaryk_ex, OAuth,
      client_id: "cid",
      client_secret: "sec",
      redirect_uri: "https://example.test/auth/discord/callback"
    )

    on_exit(fn -> Application.delete_env(:masaryk_ex, OAuth) end)
    :ok
  end

  test "authorize_url/1 builds the consent URL with the expected params" do
    url = OAuth.authorize_url("st4te")
    %URI{query: query} = URI.parse(url)
    params = URI.decode_query(query)

    assert String.starts_with?(url, "https://discord.com/api/oauth2/authorize?")
    assert params["response_type"] == "code"
    assert params["client_id"] == "cid"
    assert params["scope"] == "identify"
    assert params["state"] == "st4te"
    assert params["redirect_uri"] == "https://example.test/auth/discord/callback"
  end

  test "authorize_url/1 does not leak the client secret" do
    refute OAuth.authorize_url("st4te") =~ "sec"
  end
end
