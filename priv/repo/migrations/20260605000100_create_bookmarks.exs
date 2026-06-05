defmodule MasarykEx.Repo.Migrations.CreateBookmarks do
  use Ecto.Migration

  def change do
    create table(:bookmarks) do
      add :user_id, :string, null: false
      add :message_id, :string, null: false
      add :channel_id, :string
      add :guild_id, :string

      timestamps()
    end

    create index(:bookmarks, [:user_id])
  end
end
