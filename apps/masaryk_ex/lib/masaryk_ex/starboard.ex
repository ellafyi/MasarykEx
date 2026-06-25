defmodule MasarykEx.Starboard do
  @moduledoc """
  Dashboard-facing facade over the starboard: reads and writes the service's
  threshold/channel config (through the same `Config` + `Config.Store` mechanism
  the `/config` command uses) and lists persisted starred messages.

  Settings reads resolve through the ETS-cached `Config`; writes go through
  `Config.Store` at the global scope, so the service picks them up on the next
  event with no restart.
  """

  alias MasarykEx.Config
  alias MasarykEx.Config.Store
  alias MasarykEx.Core.Context
  alias MasarykEx.Data.Starboard.{StarredMessage, StarredMessages}
  alias MasarykEx.Services.Starboard.Definition

  @topic "starboard"
  @web_context %Context{interface: :web}

  @type settings :: %{threshold: integer(), channel_id: String.t() | nil}

  @doc "Current starboard settings (threshold + target channel)."
  @spec settings() :: settings()
  def settings do
    %{
      threshold: Config.get(Definition, :threshold, @web_context),
      channel_id: Config.get(Definition, :channel_id, @web_context)
    }
  end

  @doc "Persist starboard settings globally and broadcast the change."
  @spec update_settings(%{threshold: integer(), channel_id: String.t() | nil}) ::
          :ok | {:error, term()}
  def update_settings(%{threshold: threshold, channel_id: channel_id}) do
    feature = inspect(Definition)

    with :ok <- Store.put(feature, "threshold", "global", threshold),
         :ok <- Store.put(feature, "channel_id", "global", channel_id) do
      Phoenix.PubSub.broadcast(MasarykEx.PubSub, @topic, {:starboard, :updated})
      :ok
    end
  end

  @doc "A page of starred messages, newest first."
  @spec list(keyword()) :: [StarredMessage.t()]
  def list(opts \\ []), do: StarredMessages.list(opts)

  @doc "Total number of starred messages."
  @spec count() :: non_neg_integer()
  def count, do: StarredMessages.count()

  @doc "PubSub topic LiveViews subscribe to for live starboard updates."
  @spec topic() :: String.t()
  def topic, do: @topic
end
