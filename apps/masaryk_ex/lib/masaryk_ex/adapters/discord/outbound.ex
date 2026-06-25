defmodule MasarykEx.Adapters.Discord.Outbound do
  @moduledoc """
  Outbound Discord operations for the starboard: read a message's reaction
  counts, post to the starboard channel, and edit a prior post.

  Like `MasarykEx.Discord`, every Nostrum call goes through an injectable
  function (defaulting to the real API) so it can be stubbed in tests. IDs are
  carried as strings through the neutral core and converted to snowflakes here.
  """

  @gold 0xFFD700

  @doc "Fetch a message. Returns `{:ok, message}` or `:error`."
  @spec get_message(String.t(), String.t()) :: {:ok, map()} | :error
  def get_message(channel_id, message_id) do
    with {:ok, channel} <- to_id(channel_id),
         {:ok, message} <- to_id(message_id),
         {:ok, result} <- fetcher().(channel, message) do
      {:ok, result}
    else
      _ -> :error
    end
  end

  @doc "Post a payload to a channel. Returns `{:ok, message}` or `:error`."
  @spec create_message(String.t(), map()) :: {:ok, map()} | :error
  def create_message(channel_id, payload) do
    with {:ok, channel} <- to_id(channel_id),
         {:ok, result} <- poster().(channel, payload) do
      {:ok, result}
    else
      _ -> :error
    end
  end

  @doc "Edit a prior message. Returns `{:ok, message}` or `:error`."
  @spec edit_message(String.t(), String.t(), map()) :: {:ok, map()} | :error
  def edit_message(channel_id, message_id, payload) do
    with {:ok, channel} <- to_id(channel_id),
         {:ok, message} <- to_id(message_id),
         {:ok, result} <- editor().(channel, message, payload) do
      {:ok, result}
    else
      _ -> :error
    end
  end

  @doc "Count of a specific emoji's reactions on a fetched message."
  @spec count_for_emoji(map(), String.t()) :: non_neg_integer()
  def count_for_emoji(%{reactions: reactions}, emoji_name) when is_list(reactions) do
    Enum.find_value(reactions, 0, fn reaction ->
      if emoji_name(reaction) == emoji_name, do: reaction.count
    end)
  end

  def count_for_emoji(_message, _emoji_name), do: 0

  @doc "Build the Discord embed payload for a starboard post."
  @spec starboard_embed(map()) :: map()
  def starboard_embed(attrs) do
    embed =
      %{
        author: attrs[:author] && %{name: attrs[:author]},
        description: blank_to_nil(attrs[:content]),
        color: @gold,
        fields: [
          %{name: "Source", value: "[Jump to message](#{jump_url(attrs)})", inline: true}
        ],
        footer: %{text: "#{attrs[:emoji]} #{attrs[:reaction_count]}"}
      }
      |> Map.reject(fn {_k, v} -> is_nil(v) end)

    %{embeds: [embed]}
  end

  @doc "Permalink to the source message."
  @spec jump_url(map()) :: String.t()
  def jump_url(attrs) do
    guild = attrs[:guild_id] || "@me"
    "https://discord.com/channels/#{guild}/#{attrs[:channel_id]}/#{attrs[:message_id]}"
  end

  defp emoji_name(%{emoji: %{name: name}}), do: name
  defp emoji_name(_), do: nil

  defp to_id(value) when is_integer(value), do: {:ok, value}

  defp to_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} -> {:ok, id}
      _ -> :error
    end
  end

  defp to_id(_), do: :error

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp fetcher do
    Application.get_env(:masaryk_ex, :starboard_message_fetcher, &Nostrum.Api.Message.get/2)
  end

  defp poster do
    Application.get_env(:masaryk_ex, :starboard_message_poster, &Nostrum.Api.Message.create/2)
  end

  defp editor do
    Application.get_env(:masaryk_ex, :starboard_message_editor, &Nostrum.Api.Message.edit/3)
  end
end
