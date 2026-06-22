defmodule MasarykEx.Config.Setting do
  @moduledoc """
  A persisted runtime config override, keyed by `{feature, key, scope}` where
  `scope` is `"global"` or a guild id. `value` is jsonb wrapped in `%{"v" => term}`
  so any JSON-able value persists uniformly.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "settings" do
    field :feature, :string
    field :key, :string
    field :scope, :string
    field :value, :map

    timestamps()
  end

  @doc false
  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:feature, :key, :scope, :value])
    |> validate_required([:feature, :key, :scope, :value])
    |> unique_constraint([:feature, :key, :scope])
  end

  @doc "Wrap a raw value for jsonb storage."
  def wrap(value), do: %{"v" => value}

  @doc "Unwrap a stored jsonb value."
  def unwrap(%{"v" => value}), do: value
end
