defmodule MasarykEx.Services.MessageBackup.DefinitionTest do
  use ExUnit.Case, async: false

  alias MasarykEx.Core.{Context, Event}
  alias MasarykEx.Data.Backups.BackedUpMessages
  alias MasarykEx.Services.MessageBackup.Definition

  @config %{channel_id: "999"}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MasarykEx.Repo)
    test_pid = self()

    # Outbound.create_message posts through the :starboard_message_poster fn.
    Application.put_env(:masaryk_ex, :starboard_message_poster, fn channel, payload ->
      send(test_pid, {:posted, channel, payload})
      {:ok, %{id: 1}}
    end)

    on_exit(fn -> Application.delete_env(:masaryk_ex, :starboard_message_poster) end)
    :ok
  end

  defp event(type, data),
    do: %Event{type: type, data: data, context: %Context{interface: :discord}}

  defp created(overrides) do
    Map.merge(
      %{
        message_id: "m1",
        channel_id: "c1",
        author_id: "u1",
        author_username: "alice",
        content: "hello"
      },
      Map.new(overrides)
    )
  end

  test "message_created archives the message" do
    assert :ok = Definition.handle_event(event(:message_created, created([])), @config)
    assert BackedUpMessages.get_by_message("m1").content == "hello"
  end

  test "message_updated rewrites content and announces the edit" do
    Definition.handle_event(event(:message_created, created([])), @config)

    assert :ok =
             Definition.handle_event(
               event(:message_updated, %{
                 message_id: "m1",
                 channel_id: "c1",
                 content: "edited",
                 edited_at: nil
               }),
               @config
             )

    assert BackedUpMessages.get_by_message("m1").content == "edited"
    assert_received {:posted, 999, %{embeds: [embed]}}
    assert embed.title == "✏️ Message edited"
  end

  test "message_updated with unchanged content is a no-op" do
    Definition.handle_event(event(:message_created, created([])), @config)

    Definition.handle_event(
      event(:message_updated, %{
        message_id: "m1",
        channel_id: "c1",
        content: "hello",
        edited_at: nil
      }),
      @config
    )

    refute_received {:posted, _, _}
  end

  test "message_deleted soft-deletes and announces, quoting the archived content" do
    Definition.handle_event(event(:message_created, created(content: "secret plans")), @config)

    assert :ok =
             Definition.handle_event(
               event(:message_deleted, %{message_id: "m1", channel_id: "c1"}),
               @config
             )

    assert BackedUpMessages.get_by_message("m1").deleted_at != nil
    assert_received {:posted, 999, %{embeds: [embed]}}
    assert embed.title == "🗑️ Message deleted"
    assert embed.description == "secret plans"
  end

  test "delete of an unarchived message does nothing" do
    assert :ok =
             Definition.handle_event(
               event(:message_deleted, %{message_id: "ghost", channel_id: "c1"}),
               @config
             )

    refute_received {:posted, _, _}
  end

  test "no log channel configured still updates the DB but posts nothing" do
    Definition.handle_event(event(:message_created, created([])), %{channel_id: nil})

    Definition.handle_event(
      event(:message_deleted, %{message_id: "m1", channel_id: "c1"}),
      %{channel_id: nil}
    )

    assert BackedUpMessages.get_by_message("m1").deleted_at != nil
    refute_received {:posted, _, _}
  end
end
