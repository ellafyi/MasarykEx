defmodule MasarykEx.Adapters.Discord.Translate do
  @moduledoc """
  Translates between Nostrum's Discord types and the neutral core types. The
  only module in the Discord adapter that knows both worlds.
  """

  alias MasarykEx.Core.{Context, Event, Request, Response}

  @doc "Build a neutral Request from a Discord interaction."
  @spec to_request(map()) :: Request.t()
  def to_request(interaction) do
    %Request{
      command: interaction.data.name,
      args: options_to_args(interaction.data.options),
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
  def to_discord_response(%Response{content: content, ephemeral: ephemeral}) do
    data = %{content: content}
    data = if ephemeral, do: Map.put(data, :flags, 64), else: data
    %{type: 4, data: data}
  end

  @doc "Convert a neutral command `definition/0` into a Discord slash-command spec."
  @spec command_to_discord(map()) :: map()
  def command_to_discord(definition) do
    %{
      name: definition.name,
      description: definition.description,
      options: Enum.map(Map.get(definition, :args, []), &arg_to_option/1)
    }
  end

  @doc "Translate a Nostrum gateway event into a neutral Event, or nil to ignore it."
  @spec to_event(atom(), term()) :: Event.t() | nil
  def to_event(:MESSAGE_CREATE, msg) do
    %Event{
      type: :message_created,
      data: %{
        content: msg.content,
        author_id: maybe_string(msg.author.id),
        author_username: msg.author.username,
        message_id: maybe_string(msg.id),
        channel_id: maybe_string(msg.channel_id)
      },
      context: %Context{
        interface: :discord,
        user_id: maybe_string(msg.author.id),
        guild_id: maybe_string(msg.guild_id),
        channel_id: maybe_string(msg.channel_id)
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

  def to_event(_type, _payload), do: nil

  defp options_to_args(nil), do: %{}
  defp options_to_args(options), do: Map.new(options, &{&1.name, &1.value})

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
