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

  @doc """
  Resolve a channel's type and parent. Returns `{:ok, %{type: integer,
  parent_id: string | nil}}` or `:error`. Used to classify a reacted message's
  source as a thread/forum and to resolve the parent channel that decides
  starboard membership.
  """
  @spec channel_info(String.t()) ::
          {:ok, %{type: integer(), parent_id: String.t() | nil}} | :error
  def channel_info(channel_id) do
    with {:ok, id} <- to_id(channel_id),
         {:ok, channel} <- channel_fetcher().(id) do
      {:ok, %{type: channel.type, parent_id: maybe_id_string(channel.parent_id)}}
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

  @doc """
  First image/video/gif on a fetched message as `%{url, type}` (type is
  `:image` or `:video`), or `nil`. Uploads come through attachments; link
  previews (e.g. Tenor gifs) come through embeds. Only the URL is kept — the
  media itself is never downloaded or stored.
  """
  @spec media(map()) :: %{url: String.t(), type: :image | :video} | nil
  def media(message) do
    attachment_media(message) || embed_media(message)
  end

  defp attachment_media(%{attachments: attachments}) when is_list(attachments) do
    Enum.find_value(attachments, fn attachment ->
      with type when not is_nil(type) <- classify(attachment.filename),
           url when is_binary(url) <- attachment.url do
        %{url: url, type: type}
      else
        _ -> nil
      end
    end)
  end

  defp attachment_media(_), do: nil

  defp embed_media(%{embeds: embeds}) when is_list(embeds) do
    Enum.find_value(embeds, fn embed ->
      cond do
        url = media_part_url(embed, :video) -> %{url: url, type: :video}
        url = media_part_url(embed, :image) -> %{url: url, type: :image}
        url = media_part_url(embed, :thumbnail) -> %{url: url, type: :image}
        true -> nil
      end
    end)
  end

  defp embed_media(_), do: nil

  defp media_part_url(embed, key) do
    case Map.get(embed, key) do
      %{url: url} when is_binary(url) -> url
      _ -> nil
    end
  end

  defp classify(filename) when is_binary(filename) do
    case filename |> Path.extname() |> String.downcase() do
      ext when ext in ~w(.png .jpg .jpeg .gif .webp .bmp) -> :image
      ext when ext in ~w(.mp4 .mov .webm .mkv .avi) -> :video
      _ -> nil
    end
  end

  defp classify(_), do: nil

  @doc "Count of a specific emoji's reactions on a fetched message."
  @spec count_for_emoji(map(), String.t()) :: non_neg_integer()
  def count_for_emoji(%{reactions: reactions}, emoji_name) when is_list(reactions) do
    Enum.find_value(reactions, 0, fn reaction ->
      if emoji_name(reaction) == emoji_name, do: reaction.count
    end)
  end

  def count_for_emoji(_message, _emoji_name), do: 0

  @doc """
  Build the Discord post payload (embed plus optional content) for a starboard
  entry. Images and gifs are inlined in the embed; an uploaded video can't play
  inside one, so its filename becomes the message text instead.
  """
  @spec starboard_embed(map()) :: map()
  def starboard_embed(attrs) do
    embed =
      %{
        author: author_block(attrs),
        description: blank_to_nil(attrs[:content]),
        color: @gold,
        fields: [
          %{
            name: "Reactions",
            value: "#{render_emoji(attrs)} #{attrs[:reaction_count]}",
            inline: true
          },
          %{
            name: "Source",
            value: "<##{attrs[:channel_id]}> · [Jump to message](#{jump_url(attrs)})",
            inline: true
          }
        ]
      }
      |> put_image(attrs)
      |> Map.reject(fn {_k, v} -> is_nil(v) end)

    put_content(%{embeds: [embed]}, attrs)
  end

  defp author_block(%{author: author} = attrs) when is_binary(author) do
    maybe_put(%{name: author}, :icon_url, attrs[:author_avatar_url])
  end

  defp author_block(_attrs), do: nil

  @doc """
  Full CDN avatar URL for a fetched message's author, or `nil` when the author
  has no custom avatar. Works for both `%Nostrum.Struct.User{}` and the plain-map
  fixtures (`%{id, avatar}`).
  """
  @spec author_avatar_url(map()) :: String.t() | nil
  def author_avatar_url(%{author: %{id: id, avatar: hash}})
      when not is_nil(id) and is_binary(hash) do
    ext = if String.starts_with?(hash, "a_"), do: "gif", else: "png"
    "https://cdn.discordapp.com/avatars/#{id}/#{hash}.#{ext}"
  end

  def author_avatar_url(_message), do: nil

  @doc """
  Render the triggering reaction for the footer. A unicode emoji passes through
  as its name; a this-guild custom emoji becomes `<:name:id>` (or `<a:name:id>`
  when animated); a custom emoji from another guild falls back to text `:name:`.
  """
  @spec render_emoji(map()) :: String.t()
  def render_emoji(attrs) do
    name = attrs[:emoji]

    case attrs[:emoji_id] do
      nil ->
        name

      id ->
        if local_emoji?(attrs[:guild_id], id) do
          prefix = if attrs[:emoji_animated], do: "a", else: ""
          "<#{prefix}:#{name}:#{id}>"
        else
          ":#{name}:"
        end
    end
  end

  defp local_emoji?(nil, _id), do: false

  defp local_emoji?(guild_id, id) do
    with {:ok, guild} <- to_id(guild_id),
         {:ok, emojis} <- guild_emojis().(guild) do
      Enum.any?(emojis, fn emoji -> to_string(emoji.id) == id end)
    else
      _ -> false
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp put_image(embed, %{media_url: url, media_type: type})
       when is_binary(url) and type in ["image", :image] do
    Map.put(embed, :image, %{url: url})
  end

  defp put_image(embed, _attrs), do: embed

  defp put_content(payload, %{media_url: url, media_type: type})
       when is_binary(url) and type in ["video", :video] do
    Map.put(payload, :content, media_filename(url))
  end

  defp put_content(payload, _attrs), do: payload

  defp media_filename(url) do
    url |> URI.parse() |> Map.get(:path) |> to_string() |> Path.basename()
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

  defp maybe_id_string(nil), do: nil
  defp maybe_id_string(id), do: to_string(id)

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

  defp guild_emojis do
    Application.get_env(:masaryk_ex, :starboard_guild_emojis, &Nostrum.Api.Guild.emojis/1)
  end

  defp channel_fetcher do
    Application.get_env(:masaryk_ex, :starboard_channel_fetcher, &Nostrum.Api.Channel.get/1)
  end
end
