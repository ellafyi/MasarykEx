defmodule MasarykEx.Repo.Migrations.AddStarboardIdToStarredMessages do
  use Ecto.Migration

  def change do
    alter table(:starred_messages) do
      add(:starboard_id, references(:starboards, on_delete: :nilify_all))
    end

    create(index(:starred_messages, [:starboard_id]))
  end
end
