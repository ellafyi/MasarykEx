defmodule MasarykEx.Repo.Migrations.CreateBackupChannels do
  use Ecto.Migration

  def change do
    create table(:backup_channels) do
      add :channel_id, :string, null: false
      add :name, :string
      add :after_cursor, :string, default: "0", null: false
      add :done, :boolean, default: false, null: false
      add :message_count, :integer, default: 0, null: false
      add :last_run_at, :utc_datetime

      timestamps()
    end

    create unique_index(:backup_channels, [:channel_id])
  end
end
