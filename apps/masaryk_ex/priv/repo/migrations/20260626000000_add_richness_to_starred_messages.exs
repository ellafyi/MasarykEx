defmodule MasarykEx.Repo.Migrations.AddRichnessToStarredMessages do
  use Ecto.Migration

  def change do
    alter table(:starred_messages) do
      add(:emoji_id, :string)
      add(:emoji_animated, :boolean, default: false, null: false)
      add(:author_avatar_url, :string)
    end
  end
end
