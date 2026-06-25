defmodule MasarykEx.Services.MessageBackup.Definition do
  @moduledoc """
  Live message capture for the archive. Stores every new message, updates the
  stored copy on edit, and soft-deletes on delete. When a log channel is
  configured, edits and deletions are also announced there, quoting the archived
  copy so removed content stays visible.
  """

  use MasarykEx.Core.Service

  alias MasarykEx.Adapters.Discord.Outbound
  alias MasarykEx.Core.Event
  alias MasarykEx.Data.Backups.BackedUpMessages

  @impl true
  def config_schema, do: %{channel_id: nil}

  @impl true
  def handle_event(%Event{type: :message_created, data: data}, _config) do
    BackedUpMessages.upsert(data)
    :ok
  end

  def handle_event(%Event{type: :message_updated, data: data}, config) do
    case BackedUpMessages.get_by_message(data.message_id) do
      %{content: old} = stored when old != data.content ->
        BackedUpMessages.mark_edited(data.message_id, data)
        announce(config, edit_embed(stored, data))

      _ ->
        :ok
    end
  end

  def handle_event(%Event{type: :message_deleted, data: data}, config) do
    case BackedUpMessages.get_by_message(data.message_id) do
      nil ->
        :ok

      stored ->
        BackedUpMessages.mark_deleted(data.message_id)
        announce(config, delete_embed(stored))
    end
  end

  def handle_event(_event, _config), do: :ok

  defp announce(config, embed) do
    case blank_to_nil(config[:channel_id]) do
      nil -> :ok
      channel_id -> Outbound.create_message(channel_id, %{embeds: [embed]})
    end

    :ok
  end

  defp edit_embed(stored, data) do
    %{
      title: "✏️ Message edited",
      color: 0xFAA61A,
      author: stored.author_username && %{name: stored.author_username},
      fields: [
        %{name: "Before", value: excerpt(stored.content), inline: false},
        %{name: "After", value: excerpt(data.content), inline: false},
        %{name: "Source", value: "[Jump](#{jump_url(stored)})", inline: true}
      ]
    }
    |> Map.reject(fn {_k, v} -> is_nil(v) end)
  end

  defp delete_embed(stored) do
    %{
      title: "🗑️ Message deleted",
      color: 0xED4245,
      description: excerpt(stored.content),
      author: stored.author_username && %{name: stored.author_username},
      fields: [%{name: "Source", value: "[Jump](#{jump_url(stored)})", inline: true}]
    }
    |> Map.reject(fn {_k, v} -> is_nil(v) end)
  end

  defp jump_url(stored) do
    guild = Application.get_env(:masaryk_ex, :discord_guild_id) || "@me"
    "https://discord.com/channels/#{guild}/#{stored.channel_id}/#{stored.message_id}"
  end

  defp excerpt(nil), do: "*(empty)*"
  defp excerpt(""), do: "*(empty)*"
  defp excerpt(content) when byte_size(content) <= 500, do: content
  defp excerpt(content), do: String.slice(content, 0, 497) <> "…"

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
