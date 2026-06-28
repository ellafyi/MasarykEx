defmodule MasarykEx.Repo.Migrations.CreateStarboards do
  use Ecto.Migration

  def up do
    create table(:starboards) do
      add(:guild_id, :string, null: false)
      add(:name, :string, null: false)
      add(:target_channel_id, :string, null: false)
      add(:include_channel_ids, {:array, :string}, default: [], null: false)
      add(:exclude_channel_ids, {:array, :string}, default: [], null: false)
      add(:threshold, :integer, default: 3, null: false)
      add(:thread_threshold, :integer, default: 3, null: false)
      add(:position, :integer, default: 0, null: false)
      add(:enabled, :boolean, default: true, null: false)

      timestamps()
    end

    create(unique_index(:starboards, [:guild_id, :name]))
    create(index(:starboards, [:guild_id, :position]))

    # Start fresh: drop the stale single-board starboard config (threshold +
    # channel_id) so the new per-board model is the only source of truth.
    execute("DELETE FROM settings WHERE feature = 'MasarykEx.Services.Starboard.Definition'")
  end

  def down do
    drop(table(:starboards))
  end
end
