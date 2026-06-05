defmodule MasarykEx.Config.Store do
  @moduledoc """
  ETS-cached, write-through store for persisted config overrides. Loaded from
  Postgres on boot so `Config.get/3` reads never hit the database; writes go to
  Postgres first, then the cache. ETS key: `{feature, key, scope}`.
  """

  use GenServer

  import Ecto.Query, only: [from: 2]

  alias MasarykEx.Repo
  alias MasarykEx.Config.Setting

  require Logger

  @table :masaryk_config

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Look up an override. Returns `{:ok, value}` or `:error`."
  @spec get(String.t(), String.t(), String.t()) :: {:ok, term()} | :error
  def get(feature, key, scope) do
    case :ets.lookup(@table, {feature, key, scope}) do
      [{_, value}] -> {:ok, value}
      [] -> :error
    end
  end

  @doc "Persist an override and update the cache."
  @spec put(String.t(), String.t(), String.t(), term()) :: :ok | {:error, term()}
  def put(feature, key, scope, value) do
    GenServer.call(__MODULE__, {:put, feature, key, scope, value})
  end

  @doc "Remove an override (falls back to static defaults afterwards)."
  @spec delete(String.t(), String.t(), String.t()) :: :ok
  def delete(feature, key, scope) do
    GenServer.call(__MODULE__, {:delete, feature, key, scope})
  end

  @doc "All distinct override keys currently cached for a feature."
  @spec keys(String.t()) :: [String.t()]
  def keys(feature) do
    :ets.match(@table, {{feature, :"$1", :_}, :_})
    |> List.flatten()
    |> Enum.uniq()
  end

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:named_table, :set, :protected, read_concurrency: true])
    load_all()
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:put, feature, key, scope, value}, _from, state) do
    attrs = %{feature: feature, key: key, scope: scope, value: Setting.wrap(value)}

    result =
      %Setting{}
      |> Setting.changeset(attrs)
      |> Repo.insert(
        on_conflict: [set: [value: Setting.wrap(value), updated_at: now()]],
        conflict_target: [:feature, :key, :scope]
      )

    case result do
      {:ok, _} ->
        :ets.insert(@table, {{feature, key, scope}, value})
        {:reply, :ok, state}

      {:error, changeset} ->
        {:reply, {:error, changeset}, state}
    end
  end

  @impl true
  def handle_call({:delete, feature, key, scope}, _from, state) do
    Repo.delete_all(
      from s in Setting, where: s.feature == ^feature and s.key == ^key and s.scope == ^scope
    )

    :ets.delete(@table, {feature, key, scope})
    {:reply, :ok, state}
  end

  defp load_all do
    Repo.all(Setting)
    |> Enum.each(fn s ->
      :ets.insert(@table, {{s.feature, s.key, s.scope}, Setting.unwrap(s.value)})
    end)
  rescue
    err ->
      Logger.warning("Config.Store could not preload settings: #{Exception.message(err)}")
      :ok
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
