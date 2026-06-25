defmodule MasarykEx.Adapters.Discord.Translate do
  @moduledoc """
  Translates between Nostrum's Discord types and the neutral core types. The
  only module in the Discord adapter that knows both worlds.
  """

  alias MasarykEx.Core.{Context, Embed, Event, Request, Response}

  @doc "Build a neutral Request from a Discord interaction."
  @spec to_request(map()) :: Request.t()
  def to_request(interaction) do
    %Request{
      command: interaction.data.name,
      args: interaction_args(interaction),
      context: %Context{
        interface: :discord,
        user_id: interaction_user_id(interaction),
        guild_id: maybe_string(interaction.guild_id),
        channel_id: maybe_string(interaction.channel_id)
      }
    }
  end

  @doc "Render a neutral Response as a Discord interaction response."
  @spec to_discord_response(Response.t()) :: map()
  def to_discord_response(%Response{
        content: content,
        ephemeral: ephemeral,
        embed: embed,
        embeds: embeds
      }) do
    data =
      %{}
      |> put_content(content)
      |> put_embeds(embed, embeds)
      |> put_flags(ephemeral)

    %{type: 4, data: data}
  end

  @doc "Convert a neutral command `definition/0` into a Discord application-command spec."
  @spec command_to_discord(map()) :: map()
  def command_to_discord(definition) do
    case Map.get(definition, :type, :slash) do
      # MESSAGE context-menu command: name + type only, no description/options.
      :message ->
        %{name: definition.name, type: 3}

      :slash ->
        %{
          name: definition.name,
          description: definition.description,
          options: Enum.map(Map.get(definition, :args, []), &arg_to_option/1)
        }
    end
  end

  @doc "Translate a Nostrum gateway event into a neutral Event, or nil to ignore it."
  @spec to_event(atom(), term()) :: Event.t() | nil
  def to_event(:MESSAGE_CREATE, msg) do
    %Event{
      type: :message_created,
      data: message_data(msg),
      context: %Context{
        interface: :discord,
        user_id: maybe_string(msg.author.id),
        guild_id: maybe_string(msg.guild_id),
        channel_id: maybe_string(msg.channel_id)
      }
    }
  end

  # MESSAGE_UPDATE arrives as a {old_message, updated_message} tuple.
  def to_event(:MESSAGE_UPDATE, {_old, msg}) do
    %Event{
      type: :message_updated,
      data: %{
        message_id: maybe_string(msg.id),
        channel_id: maybe_string(msg.channel_id),
        content: msg.content,
        edited_at: msg.edited_timestamp
      },
      context: %Context{
        interface: :discord,
        guild_id: maybe_string(msg.guild_id),
        channel_id: maybe_string(msg.channel_id)
      }
    }
  end

  def to_event(:MESSAGE_DELETE, deletion) do
    %Event{
      type: :message_deleted,
      data: %{
        message_id: maybe_string(deletion.id),
        channel_id: maybe_string(deletion.channel_id)
      },
      context: %Context{
        interface: :discord,
        guild_id: maybe_string(Map.get(deletion, :guild_id)),
        channel_id: maybe_string(deletion.channel_id)
      }
    }
  end

  def to_event(:MESSAGE_REACTION_ADD, reaction) do
    %Event{
      type: :reaction_added,
      data: %{
        emoji_name: reaction.emoji.name,
        message_id: maybe_string(reaction.message_id),
        user_id: maybe_string(reaction.user_id),
        channel_id: maybe_string(reaction.channel_id)
      },
      context: %Context{
        interface: :discord,
        user_id: maybe_string(reaction.user_id),
        guild_id: maybe_string(reaction.guild_id),
        channel_id: maybe_string(reaction.channel_id)
      }
    }
  end

  def to_event(:MESSAGE_REACTION_REMOVE, reaction) do
    %Event{
      type: :reaction_removed,
      data: %{
        emoji_name: reaction.emoji.name,
        message_id: maybe_string(reaction.message_id),
        user_id: maybe_string(reaction.user_id),
        channel_id: maybe_string(reaction.channel_id)
      },
      context: %Context{
        interface: :discord,
        user_id: maybe_string(reaction.user_id),
        guild_id: maybe_string(reaction.guild_id),
        channel_id: maybe_string(reaction.channel_id)
      }
    }
  end

  def to_event(_type, _payload), do: nil

  # Full archival view of a message, shared by live capture and history backfill.
  defp message_data(msg) do
    %{
      content: msg.content,
      author_id: maybe_string(msg.author.id),
      author_username: msg.author.username,
      message_id: maybe_string(msg.id),
      channel_id: maybe_string(msg.channel_id),
      posted_at: msg.timestamp,
      edited_at: msg.edited_timestamp,
      type: msg.type,
      pinned: msg.pinned,
      reply_to_message_id: referenced_id(msg),
      attachment_urls: attachment_urls(msg)
    }
  end

  defp referenced_id(%{referenced_message: %{id: id}}) when not is_nil(id), do: maybe_string(id)

  defp referenced_id(%{message_reference: %{message_id: id}}) when not is_nil(id),
    do: maybe_string(id)

  defp referenced_id(_), do: nil

  defp attachment_urls(%{attachments: attachments}) when is_list(attachments) do
    Enum.map(attachments, & &1.url)
  end

  defp attachment_urls(_), do: []

  # MESSAGE context-menu command (type 3): pull the resolved target message.
  defp interaction_args(%{data: %{type: 3, target_id: target_id, resolved: resolved}}) do
    message = resolved.messages[target_id]

    %{
      "message" => %{
        "id" => maybe_string(message.id),
        "content" => message.content,
        "author" => message.author.username,
        "author_id" => maybe_string(message.author.id),
        "channel_id" => maybe_string(message.channel_id)
      }
    }
  end

  # Slash command (type 1): options become named args.
  defp interaction_args(%{data: %{options: options}}), do: options_to_args(options)

  defp options_to_args(nil), do: %{}
  defp options_to_args(options), do: Map.new(options, &{&1.name, &1.value})

  defp put_content(data, ""), do: data
  defp put_content(data, content), do: Map.put(data, :content, content)

  defp put_embeds(data, nil, []), do: data

  defp put_embeds(data, embed, embeds) do
    all = List.wrap(embed && discord_embed(embed)) ++ Enum.map(embeds, &discord_embed/1)
    Map.put(data, :embeds, all)
  end

  defp put_flags(data, true), do: Map.put(data, :flags, 64)
  defp put_flags(data, false), do: data

  defp discord_embed(%Embed{} = embed) do
    %{
      title: embed.title,
      description: embed.description,
      color: embed.color,
      footer: embed.footer && %{text: embed.footer},
      fields: Enum.map(embed.fields, &embed_field/1)
    }
    |> Map.reject(fn {_k, v} -> is_nil(v) end)
  end

  defp embed_field(field) do
    %{name: field.name, value: field.value, inline: Map.get(field, :inline, false)}
  end

  defp interaction_user_id(%{member: %{user: %{id: id}}}), do: maybe_string(id)
  defp interaction_user_id(%{user: %{id: id}}), do: maybe_string(id)
  defp interaction_user_id(_), do: nil

  defp arg_to_option(arg) do
    %{
      type: option_type(Map.get(arg, :type, :string)),
      name: arg.name,
      description: Map.get(arg, :description, arg.name),
      required: Map.get(arg, :required, false)
    }
  end

  defp option_type(:string), do: 3
  defp option_type(:integer), do: 4
  defp option_type(:boolean), do: 5
  defp option_type(:user), do: 6
  defp option_type(:number), do: 10
  defp option_type(_), do: 3

  defp maybe_string(nil), do: nil
  defp maybe_string(value), do: to_string(value)
end
