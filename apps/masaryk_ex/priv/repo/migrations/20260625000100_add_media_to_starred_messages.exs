defmodule MasarykEx.Repo.Migrations.AddMediaToStarredMessages do
  use Ecto.Migration

  def change do
    alter table(:starred_messages) do
      add(:media_url, :text)
      add(:media_type, :string)
    end
  end
end
