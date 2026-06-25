defmodule MasarykEx.Repo.Migrations.CreateStarredMessages do
  use Ecto.Migration

  def change do
    create table(:starred_messages) do
      add(:message_id, :string, null: false)
      add(:channel_id, :string)
      add(:guild_id, :string)
      add(:author, :string)
      add(:content, :text)
      add(:emoji, :string, null: false)
      add(:reaction_count, :integer, null: false, default: 0)
      add(:starboard_message_id, :string)

      timestamps()
    end

    create(unique_index(:starred_messages, [:message_id]))
  end
end
