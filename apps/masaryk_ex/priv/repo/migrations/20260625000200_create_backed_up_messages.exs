defmodule MasarykEx.Repo.Migrations.CreateBackedUpMessages do
  use Ecto.Migration

  def change do
    create table(:backed_up_messages) do
      add :message_id, :string, null: false
      add :channel_id, :string
      add :author_id, :string
      add :author_username, :string
      add :content, :text
      add :posted_at, :utc_datetime
      add :edited_at, :utc_datetime
      add :deleted_at, :utc_datetime
      add :type, :integer
      add :pinned, :boolean, default: false, null: false
      add :reply_to_message_id, :string
      add :attachment_urls, {:array, :text}, default: [], null: false

      timestamps()
    end

    create unique_index(:backed_up_messages, [:message_id])
    create index(:backed_up_messages, [:channel_id])
    create index(:backed_up_messages, [:posted_at])

    execute(
      """
      ALTER TABLE backed_up_messages
      ADD COLUMN search_vector tsvector
      GENERATED ALWAYS AS (to_tsvector('simple', coalesce(content, ''))) STORED
      """,
      "ALTER TABLE backed_up_messages DROP COLUMN search_vector"
    )

    execute(
      "CREATE INDEX backed_up_messages_search_vector_index ON backed_up_messages USING gin (search_vector)",
      "DROP INDEX backed_up_messages_search_vector_index"
    )
  end
end
