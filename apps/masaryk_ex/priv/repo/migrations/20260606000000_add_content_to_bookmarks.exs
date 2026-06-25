defmodule MasarykEx.Repo.Migrations.AddContentToBookmarks do
  use Ecto.Migration

  def change do
    alter table(:bookmarks) do
      add :content, :text
      add :author, :string
    end
  end
end
