defmodule MasarykEx.Repo.Migrations.CreateSettings do
  use Ecto.Migration

  def change do
    create table(:settings) do
      add :feature, :string, null: false
      add :key, :string, null: false
      add :scope, :string, null: false
      add :value, :map, null: false

      timestamps()
    end

    create unique_index(:settings, [:feature, :key, :scope])
  end
end
